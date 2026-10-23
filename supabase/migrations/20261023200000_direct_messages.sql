-- Direct messages between mutual followers (issue #13).
-- 1:1 only: a conversation is the pair (user_a < user_b). Blocking or unfollowing ends it:
-- no new messages, and a block also hides the history.

-- Both follow each other and neither blocked the other.
create or replace function private.can_message(other uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select other <> (select auth.uid())
     and exists (select 1 from public.follows
                 where follower_id = (select auth.uid()) and following_id = other)
     and exists (select 1 from public.follows
                 where follower_id = other and following_id = (select auth.uid()))
     and not private.is_blocked_with(other);
$$;
revoke all on function private.can_message(uuid) from public, anon;
grant execute on function private.can_message(uuid) to authenticated;

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  a_read_at timestamptz,
  b_read_at timestamptz,
  check (user_a < user_b),
  unique (user_a, user_b)
);
create index if not exists conversations_user_b_idx on public.conversations (user_b);

alter table public.conversations enable row level security;
revoke all on public.conversations from anon, authenticated;
grant select on public.conversations to authenticated;

drop policy if exists "Members see own conversations" on public.conversations;
create policy "Members see own conversations" on public.conversations
  for select to authenticated using (
    (select auth.uid()) in (user_a, user_b)
    and not private.is_blocked_with(case when user_a = (select auth.uid()) then user_b else user_a end)
  );

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc);
create index if not exists messages_sender_id_idx on public.messages (sender_id);

alter table public.messages enable row level security;
revoke all on public.messages from anon, authenticated;
grant select on public.messages to authenticated;
grant insert (conversation_id, body) on public.messages to authenticated;

-- Visible with the conversation (members only, hidden after a block).
drop policy if exists "Members read messages" on public.messages;
create policy "Members read messages" on public.messages
  for select to authenticated using (
    exists (select 1 from public.conversations c where c.id = conversation_id)
  );

-- Sending needs a live mutual follow.
drop policy if exists "Mutual followers send messages" on public.messages;
create policy "Mutual followers send messages" on public.messages
  for insert to authenticated with check (
    sender_id = (select auth.uid())
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (select auth.uid()) in (c.user_a, c.user_b)
        and private.can_message(case when c.user_a = (select auth.uid()) then c.user_b else c.user_a end)
    )
  );

-- New message bumps the conversation and counts as read for the sender.
create or replace function private.touch_conversation()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.conversations
     set last_message_at = new.created_at,
         a_read_at = case when user_a = new.sender_id then new.created_at else a_read_at end,
         b_read_at = case when user_b = new.sender_id then new.created_at else b_read_at end
   where id = new.conversation_id;
  return new;
end;
$$;
revoke all on function private.touch_conversation() from public, anon, authenticated;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
  after insert on public.messages
  for each row execute function private.touch_conversation();

-- Rate limit: same trigger as posts/comments, plus messages (60 per 10 minutes).
create or replace function private.enforce_rate_limit()
returns trigger
language plpgsql security definer set search_path to 'public' as $function$
declare
  n int;
begin
  if coalesce(current_setting('role', true), 'none') not in ('authenticated', 'anon') then
    return new;
  end if;
  new.created_at := now();
  perform pg_advisory_xact_lock(hashtext(tg_table_name || coalesce(auth.uid()::text, '')));
  if tg_table_name = 'posts' then
    select count(*) into n from public.posts
    where author_id = auth.uid() and created_at > now() - interval '10 minutes';
    if n >= 10 then raise exception 'rate_limit' using hint = 'posts'; end if;
  elsif tg_table_name = 'comments' then
    select count(*) into n from public.comments
    where author_id = auth.uid() and created_at > now() - interval '10 minutes';
    if n >= 30 then raise exception 'rate_limit' using hint = 'comments'; end if;
  elsif tg_table_name = 'reports' then
    select count(*) into n from public.reports
    where reporter_id = auth.uid() and created_at > now() - interval '1 day';
    if n >= 20 then raise exception 'rate_limit' using hint = 'reports'; end if;
  elsif tg_table_name = 'groups' then
    select count(*) into n from public.groups
    where creator_id = auth.uid() and created_at > now() - interval '1 day';
    if n >= 5 then raise exception 'rate_limit' using hint = 'groups'; end if;
  elsif tg_table_name = 'messages' then
    select count(*) into n from public.messages
    where sender_id = auth.uid() and created_at > now() - interval '10 minutes';
    if n >= 60 then raise exception 'rate_limit' using hint = 'messages'; end if;
  end if;
  return new;
end;
$function$;

drop trigger if exists messages_rate_limit on public.messages;
create trigger messages_rate_limit
  before insert on public.messages
  for each row execute function private.enforce_rate_limit();

-- Opens (or returns) the conversation with a mutual follower.
create or replace function public.start_conversation(p_other uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  cid uuid;
begin
  if me is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if not private.can_message(p_other) then
    raise exception 'not mutual followers' using errcode = '42501';
  end if;
  insert into public.conversations (user_a, user_b)
    values (least(me, p_other), greatest(me, p_other))
    on conflict (user_a, user_b) do nothing
    returning id into cid;
  if cid is null then
    select id into cid from public.conversations
     where user_a = least(me, p_other) and user_b = greatest(me, p_other);
  end if;
  return cid;
end;
$$;
revoke all on function public.start_conversation(uuid) from public, anon;
grant execute on function public.start_conversation(uuid) to authenticated;

create or replace function public.mark_conversation_read(p_conversation uuid)
returns void
language sql security definer set search_path = '' as $$
  update public.conversations
     set a_read_at = case when user_a = auth.uid() then now() else a_read_at end,
         b_read_at = case when user_b = auth.uid() then now() else b_read_at end
   where id = p_conversation and auth.uid() in (user_a, user_b);
$$;
revoke all on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

-- Inbox: one row per conversation with the other member and the latest message.
create or replace function public.my_conversations()
returns table (
  conversation_id uuid, other_id uuid, last_body text, last_sender_id uuid,
  last_message_at timestamptz, unread boolean, can_send boolean
)
language sql stable security invoker set search_path = '' as $$
  select c.id,
         o.other,
         m.body,
         m.sender_id,
         c.last_message_at,
         c.last_message_at is not null
           and c.last_message_at > coalesce(case when c.user_a = auth.uid() then c.a_read_at else c.b_read_at end, '-infinity'),
         private.can_message(o.other)
  from public.conversations c
  cross join lateral (select case when c.user_a = auth.uid() then c.user_b else c.user_a end as other) o
  left join lateral (
    select body, sender_id from public.messages
     where conversation_id = c.id order by created_at desc limit 1
  ) m on true
  where c.last_message_at is not null
  order by c.last_message_at desc;
$$;
revoke all on function public.my_conversations() from public, anon;
grant execute on function public.my_conversations() to authenticated;

-- Realtime for new messages (RLS applies to subscribers).
do $$ begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;
