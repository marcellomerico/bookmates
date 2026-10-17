-- Follow-up to 20261016120000 (Supabase advisors):
-- 1. RLS helper functions move to a non-exposed schema, so they are no longer callable
--    via /rest/v1/rpc (is_blocked_with revealed whether someone blocked you).
-- 2. Trigger functions are not callable as RPC.
-- 3. Covering indexes for foreign keys used by RLS checks, feeds and cascades.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- Policies reference functions by OID, so they keep working after the move.
alter function public.is_group_member(uuid) set schema private;
alter function public.can_view_group(uuid) set schema private;
alter function public.is_blocked_with(uuid) set schema private;
alter function public.can_view_post(uuid) set schema private;

-- Bodies resolve names at run time: re-point the cross-calls to private.*.
create or replace function private.can_view_group(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.groups g
    where g.id = gid
      and (g.is_private = false or g.creator_id = auth.uid() or private.is_group_member(gid))
  );
$$;

create or replace function private.can_view_post(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.posts p
    where p.id = pid
      and (p.group_id is null or private.can_view_group(p.group_id))
      and not private.is_blocked_with(p.author_id)
  );
$$;

create or replace function public.join_group_with_code(code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  gid uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  -- Blocked with the creator: same error, so the block is not revealed.
  select g.id into gid from public.groups g
  where g.invite_code = lower(trim(code)) and not private.is_blocked_with(g.creator_id);
  if gid is null then
    raise exception 'Invalid invite code' using errcode = 'P0002';
  end if;
  insert into public.group_members (group_id, user_id, role)
  values (gid, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;
  return gid;
end;
$$;

-- Trigger functions run regardless of EXECUTE; nobody should call them via RPC.
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.remove_follows_on_block() from public, anon, authenticated;
revoke all on function public.rotate_invite_on_private() from public, anon, authenticated;

create index if not exists blocks_blocked_id_idx on public.blocks (blocked_id);
create index if not exists comments_post_id_idx on public.comments (post_id);
create index if not exists comments_author_id_idx on public.comments (author_id);
create index if not exists follows_following_id_idx on public.follows (following_id);
create index if not exists group_members_user_id_idx on public.group_members (user_id);
create index if not exists groups_creator_id_idx on public.groups (creator_id);
create index if not exists groups_genre_id_idx on public.groups (genre_id);
create index if not exists likes_user_id_idx on public.likes (user_id);
create index if not exists posts_author_id_idx on public.posts (author_id);
create index if not exists posts_book_id_idx on public.posts (book_id);
create index if not exists posts_group_id_idx on public.posts (group_id);
create index if not exists reports_comment_id_idx on public.reports (comment_id);
create index if not exists reports_post_id_idx on public.reports (post_id);
create index if not exists reports_reported_user_id_idx on public.reports (reported_user_id);
create index if not exists reports_reporter_id_idx on public.reports (reporter_id);
create index if not exists user_books_book_id_idx on public.user_books (book_id);
create index if not exists user_genres_genre_id_idx on public.user_genres (genre_id);
