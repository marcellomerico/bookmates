-- Private accounts with follow requests (issue #12).
-- Private: others see only the profile card; shelf, wishlist and posts after an accepted request.
-- Reading-circle posts stay visible to circle members. Existing accounts stay public.

alter table public.profiles
  add column if not exists is_private boolean not null default false;

-- True when the caller may see the owner's shelf and posts.
create or replace function private.can_see_content(owner uuid)
returns boolean
language sql stable security definer set search_path = '' as $$
  select owner = (select auth.uid())
      or not coalesce((select p.is_private from public.profiles p where p.id = owner), false)
      or exists (
        select 1 from public.follows f
        where f.follower_id = (select auth.uid()) and f.following_id = owner
      );
$$;
revoke all on function private.can_see_content(uuid) from public, anon;
grant execute on function private.can_see_content(uuid) to authenticated;

drop policy if exists "User books visible to signed-in users" on public.user_books;
drop policy if exists "User books visible by privacy" on public.user_books;
create policy "User books visible by privacy" on public.user_books
  for select to authenticated using (private.can_see_content(user_id));

drop policy if exists "Posts visible by visibility rules" on public.posts;
create policy "Posts visible by visibility rules" on public.posts
  for select to authenticated using (
    (case when group_id is null then private.can_see_content(author_id)
          else private.can_view_group(group_id) end)
    and not private.is_blocked_with(author_id)
    and (hidden_at is null or author_id = (select auth.uid()))
  );

-- Comments and likes follow their post.
create or replace function private.can_view_post(pid uuid)
returns boolean
language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.posts p
    where p.id = pid
      and (case when p.group_id is null then private.can_see_content(p.author_id)
                else private.can_view_group(p.group_id) end)
      and not private.is_blocked_with(p.author_id)
      and (p.hidden_at is null or p.author_id = auth.uid())
  );
$$;

-- Direct follows only for public accounts; private ones go through follow_user().
drop policy if exists "Users follow unblocked users" on public.follows;
create policy "Users follow unblocked users" on public.follows
  for insert to authenticated with check (
    follower_id = (select auth.uid())
    and not private.is_blocked_with(following_id)
    and not coalesce((select p.is_private from public.profiles p where p.id = following_id), false)
  );

create table if not exists public.follow_requests (
  requester_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (requester_id, target_id),
  check (requester_id <> target_id)
);
create index if not exists follow_requests_target_id_idx on public.follow_requests (target_id);

alter table public.follow_requests enable row level security;
revoke all on public.follow_requests from anon, authenticated;
grant select, delete on public.follow_requests to authenticated;

drop policy if exists "Users see own follow requests" on public.follow_requests;
create policy "Users see own follow requests" on public.follow_requests
  for select to authenticated
  using (requester_id = (select auth.uid()) or target_id = (select auth.uid()));

-- Requester cancels, target declines.
drop policy if exists "Users withdraw or decline follow requests" on public.follow_requests;
create policy "Users withdraw or decline follow requests" on public.follow_requests
  for delete to authenticated
  using (requester_id = (select auth.uid()) or target_id = (select auth.uid()));

-- Follows a public account or asks a private one. Returns 'following' or 'requested'.
create or replace function public.follow_user(p_target uuid)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  is_priv boolean;
begin
  if me is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  if p_target = me then
    raise exception 'cannot follow yourself' using errcode = '22023';
  end if;
  select p.is_private into is_priv from public.profiles p where p.id = p_target;
  if not found then
    raise exception 'profile not found' using errcode = 'P0002';
  end if;
  if private.is_blocked_with(p_target) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.follows where follower_id = me and following_id = p_target) then
    return 'following';
  end if;
  if is_priv then
    insert into public.follow_requests (requester_id, target_id)
      values (me, p_target) on conflict do nothing;
    return 'requested';
  end if;
  insert into public.follows (follower_id, following_id)
    values (me, p_target) on conflict do nothing;
  return 'following';
end;
$$;
revoke all on function public.follow_user(uuid) from public, anon;
grant execute on function public.follow_user(uuid) to authenticated;

create or replace function public.respond_follow_request(p_requester uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
begin
  delete from public.follow_requests
   where requester_id = p_requester and target_id = me;
  if not found then
    raise exception 'request not found' using errcode = 'P0002';
  end if;
  if p_accept then
    insert into public.follows (follower_id, following_id)
      values (p_requester, me) on conflict do nothing;
  end if;
end;
$$;
revoke all on function public.respond_follow_request(uuid, boolean) from public, anon;
grant execute on function public.respond_follow_request(uuid, boolean) to authenticated;

-- Going public accepts every open request.
create or replace function private.accept_requests_on_public()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.follows (follower_id, following_id)
    select r.requester_id, r.target_id from public.follow_requests r
     where r.target_id = new.id
    on conflict do nothing;
  delete from public.follow_requests where target_id = new.id;
  return new;
end;
$$;
revoke all on function private.accept_requests_on_public() from public, anon, authenticated;

drop trigger if exists profiles_accept_requests_on_public on public.profiles;
create trigger profiles_accept_requests_on_public
  after update of is_private on public.profiles
  for each row when (old.is_private and not new.is_private)
  execute function private.accept_requests_on_public();

-- A block also drops pending requests in both directions.
create or replace function private.remove_follow_requests_on_block()
returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.follow_requests
   where (requester_id = new.blocker_id and target_id = new.blocked_id)
      or (requester_id = new.blocked_id and target_id = new.blocker_id);
  return new;
end;
$$;
revoke all on function private.remove_follow_requests_on_block() from public, anon, authenticated;

drop trigger if exists on_block_remove_follow_requests on public.blocks;
create trigger on_block_remove_follow_requests
  after insert or update on public.blocks
  for each row execute function private.remove_follow_requests_on_block();
