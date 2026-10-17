-- Phase 2: moderation workflow + rate limits.
-- Admins are managed via SQL only:  insert into private.admins (user_id) values ('<auth uid>');

create table if not exists private.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
revoke all on private.admins from public, anon, authenticated;
-- No policies: only definer code (is_admin) reads it.
alter table private.admins enable row level security;

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from private.admins where user_id = auth.uid());
$$;
revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

create or replace function public.am_i_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select private.is_admin();
$$;
revoke all on function public.am_i_admin() from public, anon;
grant execute on function public.am_i_admin() to authenticated;

-- ---------- Hidden content (auto-hide or admin); authors still see their own ----------
alter table public.posts add column if not exists hidden_at timestamptz;
alter table public.comments add column if not exists hidden_at timestamptz;

create or replace function private.can_view_post(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.posts p
    where p.id = pid
      and (p.group_id is null or private.can_view_group(p.group_id))
      and not private.is_blocked_with(p.author_id)
      and (p.hidden_at is null or p.author_id = auth.uid())
  );
$$;

drop policy if exists "Posts visible by visibility rules" on public.posts;
create policy "Posts visible by visibility rules" on public.posts
  for select to authenticated
  using (
    (group_id is null or private.can_view_group(group_id))
    and not private.is_blocked_with(author_id)
    and (hidden_at is null or author_id = auth.uid())
  );

drop policy if exists "Comments visible with post" on public.comments;
create policy "Comments visible with post" on public.comments
  for select to authenticated
  using (
    private.can_view_post(post_id)
    and not private.is_blocked_with(author_id)
    and (hidden_at is null or author_id = auth.uid())
  );

-- Only definer code (admin RPCs, auto-hide trigger) may change hidden_at.
create or replace function private.protect_hidden_at()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.hidden_at is distinct from old.hidden_at and current_user in ('authenticated', 'anon') then
    raise exception 'hidden_at is managed by moderation' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists posts_protect_hidden_at on public.posts;
create trigger posts_protect_hidden_at before update on public.posts
  for each row execute function private.protect_hidden_at();
drop trigger if exists comments_protect_hidden_at on public.comments;
create trigger comments_protect_hidden_at before update on public.comments
  for each row execute function private.protect_hidden_at();

create or replace function private.clear_hidden_on_insert()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.hidden_at := null;
  end if;
  return new;
end;
$$;
drop trigger if exists posts_clear_hidden on public.posts;
create trigger posts_clear_hidden before insert on public.posts
  for each row execute function private.clear_hidden_on_insert();
drop trigger if exists comments_clear_hidden on public.comments;
create trigger comments_clear_hidden before insert on public.comments
  for each row execute function private.clear_hidden_on_insert();

-- ---------- Reports workflow ----------
alter table public.reports
  add column if not exists status text not null default 'open',
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references auth.users(id) on delete set null;
alter table public.reports
  add constraint reports_status_valid check (status in ('open', 'dismissed', 'actioned'));

-- What was reported, fixed at insert: post_id/comment_id are nulled when content is deleted,
-- and comment reports also carry post_id (the app sends both).
alter table public.reports add column if not exists target_type text;
update public.reports
set target_type = case when comment_id is not null then 'comment'
                       when post_id is not null then 'post' else 'user' end
where target_type is null;
alter table public.reports alter column target_type set not null;
alter table public.reports
  add constraint reports_target_type_valid check (target_type in ('post', 'comment', 'user'));

-- Fires for every caller. Named so it sorts before reports_rate_limit (BEFORE triggers run
-- alphabetically); the two do not depend on each other either way.
create or replace function private.set_report_defaults()
returns trigger language plpgsql set search_path = public as $$
begin
  new.target_type := case when new.comment_id is not null then 'comment'
                          when new.post_id is not null then 'post' else 'user' end;
  if new.target_type = 'user' and new.reported_user_id is null then
    raise exception 'Report has no target' using errcode = '23514';
  end if;
  if coalesce(current_setting('role', true), 'none') in ('authenticated', 'anon') then
    new.status := 'open';
    new.resolved_at := null;
    new.resolved_by := null;
  end if;
  return new;
end;
$$;
drop trigger if exists reports_defaults on public.reports;
create trigger reports_defaults before insert on public.reports
  for each row execute function private.set_report_defaults();

-- Users may only report content they can see; a comment must belong to the given post.
-- (Unqualified names in the subquery would bind to comments, hence reports.*.)
drop policy if exists "Users create reports" on public.reports;
create policy "Users create reports" on public.reports for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and (reports.post_id is null or private.can_view_post(reports.post_id))
    and (reports.comment_id is null or exists (
          select 1 from public.comments c
          where c.id = reports.comment_id
            and (reports.post_id is null or c.post_id = reports.post_id)))
  );

-- One report per reporter and target (keeps auto-hide counts honest). Rows whose content was
-- deleted keep their target_type with a NULL id, which never conflicts.
create unique index if not exists reports_unique_post on public.reports (reporter_id, post_id)
  where target_type = 'post';
create unique index if not exists reports_unique_comment on public.reports (reporter_id, comment_id)
  where target_type = 'comment';
create unique index if not exists reports_unique_user on public.reports (reporter_id, reported_user_id)
  where target_type = 'user';
create index if not exists reports_open_idx on public.reports (created_at) where status = 'open';

create or replace function private.auto_hide_reported()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.target_type = 'post' and new.post_id is not null and (
    select count(distinct reporter_id) from public.reports
    where target_type = 'post' and post_id = new.post_id and status = 'open') >= 3 then
    update public.posts set hidden_at = now() where id = new.post_id and hidden_at is null;
  end if;
  if new.target_type = 'comment' and new.comment_id is not null and (
    select count(distinct reporter_id) from public.reports
    where target_type = 'comment' and comment_id = new.comment_id and status = 'open') >= 3 then
    update public.comments set hidden_at = now() where id = new.comment_id and hidden_at is null;
  end if;
  return new;
end;
$$;
drop trigger if exists reports_auto_hide on public.reports;
create trigger reports_auto_hide after insert on public.reports
  for each row execute function private.auto_hide_reported();

-- ---------- Admin RPCs ----------
-- Returns nothing for non-admins.
create or replace function public.admin_open_reports()
returns table (
  report_id uuid, reported_at timestamptz, reason text, reporter_username text,
  target_user_id uuid, target_username text, target_post_id uuid, target_comment_id uuid,
  content text, content_hidden boolean
)
language sql stable security definer set search_path = public as $$
  select r.id, r.created_at, r.reason, rp.username,
         coalesce(r.reported_user_id, c.author_id, p.author_id), tu.username,
         r.post_id, r.comment_id,
         case when r.target_type = 'comment' then c.content else p.content end,
         case when r.target_type = 'comment' then c.hidden_at else p.hidden_at end is not null
  from public.reports r
  left join public.profiles rp on rp.id = r.reporter_id
  left join public.comments c on c.id = r.comment_id
  left join public.posts p on p.id = r.post_id
  left join public.profiles tu on tu.id = coalesce(r.reported_user_id, c.author_id, p.author_id)
  where private.is_admin() and r.status = 'open'
  order by r.created_at;
$$;
revoke all on function public.admin_open_reports() from public, anon;
grant execute on function public.admin_open_reports() to authenticated;

-- p_action: 'dismiss' (restore content), 'hide', 'delete'. Resolves all open reports on the same target.
create or replace function public.admin_resolve_report(p_report_id uuid, p_action text)
returns void language plpgsql security definer set search_path = public as $$
declare
  r public.reports%rowtype;
begin
  if not private.is_admin() then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_action not in ('dismiss', 'hide', 'delete') then
    raise exception 'Invalid action' using errcode = '22023';
  end if;
  select * into r from public.reports where id = p_report_id for update;
  if not found then
    raise exception 'Report not found' using errcode = 'P0002';
  end if;

  if p_action <> 'dismiss' and r.target_type = 'user' then
    raise exception 'No content target' using errcode = '22023';
  end if;

  -- Resolve first: deleting content nulls reports.post_id/comment_id (on delete set null).
  update public.reports
  set status = case when p_action = 'dismiss' then 'dismissed' else 'actioned' end,
      resolved_at = now(), resolved_by = auth.uid()
  where id = r.id
     or (status = 'open' and target_type = r.target_type and (
           (r.target_type = 'post' and post_id = r.post_id)
        or (r.target_type = 'comment' and comment_id = r.comment_id)
        or (r.target_type = 'user' and reported_user_id = r.reported_user_id)));

  if p_action = 'hide' then
    if r.target_type = 'comment' then
      update public.comments set hidden_at = coalesce(hidden_at, now()) where id = r.comment_id;
    else
      update public.posts set hidden_at = coalesce(hidden_at, now()) where id = r.post_id;
    end if;
  elsif p_action = 'delete' then
    if r.target_type = 'comment' then
      delete from public.comments where id = r.comment_id;
    else
      -- The cascade removes the post's comments; close their open reports too.
      update public.reports
      set status = 'actioned', resolved_at = now(), resolved_by = auth.uid()
      where status = 'open' and target_type = 'comment'
        and comment_id in (select c.id from public.comments c where c.post_id = r.post_id);
      delete from public.posts where id = r.post_id;
    end if;
  -- dismiss: restore only if no admin ever actioned this target (keeps admin hides in place).
  elsif r.target_type = 'comment' then
    if not exists (select 1 from public.reports
                   where target_type = 'comment' and comment_id = r.comment_id and status = 'actioned') then
      update public.comments set hidden_at = null where id = r.comment_id;
    end if;
  elsif r.target_type = 'post' then
    if not exists (select 1 from public.reports
                   where target_type = 'post' and post_id = r.post_id and status = 'actioned') then
      update public.posts set hidden_at = null where id = r.post_id;
    end if;
  end if;
end;
$$;
revoke all on function public.admin_resolve_report(uuid, text) from public, anon;
grant execute on function public.admin_resolve_report(uuid, text) to authenticated;

-- ---------- Rate limits (raise 'rate_limit'; client shows a friendly message) ----------
create or replace function private.enforce_rate_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  -- current_user is the owner inside SECURITY DEFINER; the session role tells API callers apart.
  if coalesce(current_setting('role', true), 'none') not in ('authenticated', 'anon') then
    return new;
  end if;
  -- Clients must not backdate rows out of the window; count by the caller, not the row.
  new.created_at := now();
  -- Serialize concurrent inserts per caller and table so parallel requests cannot all pass.
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
  end if;
  return new;
end;
$$;
drop trigger if exists posts_rate_limit on public.posts;
create trigger posts_rate_limit before insert on public.posts for each row execute function private.enforce_rate_limit();
drop trigger if exists comments_rate_limit on public.comments;
create trigger comments_rate_limit before insert on public.comments for each row execute function private.enforce_rate_limit();
drop trigger if exists reports_rate_limit on public.reports;
create trigger reports_rate_limit before insert on public.reports for each row execute function private.enforce_rate_limit();
drop trigger if exists groups_rate_limit on public.groups;
create trigger groups_rate_limit before insert on public.groups for each row execute function private.enforce_rate_limit();

create index if not exists posts_author_created_idx on public.posts (author_id, created_at);
create index if not exists comments_author_created_idx on public.comments (author_id, created_at);

-- Trigger functions fire regardless of EXECUTE; nobody should call them via RPC.
revoke all on function private.protect_hidden_at(), private.clear_hidden_on_insert(),
  private.auto_hide_reported(), private.enforce_rate_limit(), private.set_report_defaults()
  from public, anon, authenticated;
