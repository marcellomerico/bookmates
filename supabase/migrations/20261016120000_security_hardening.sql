-- Phase 1 security hardening.
-- Requires migrations 20260707180000, 20260731120000, 20260731140000.
-- 20260731150000 is optional (its delete_own_account() is dropped here).
-- Fixes: private-group self-join, leaking comments/likes, posting into foreign groups,
-- client-only blocking, anon scraping, unbounded input, username collisions, storage abuse.

-- =====================================================================
-- Helpers. SECURITY DEFINER so policies can check membership/blocks
-- without recursing into (or being hidden by) the RLS of those tables.
-- =====================================================================
create or replace function public.is_group_member(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

create or replace function public.can_view_group(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.groups g
    where g.id = gid
      and (g.is_private = false or g.creator_id = auth.uid() or public.is_group_member(gid))
  );
$$;

create or replace function public.is_blocked_with(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = auth.uid() and blocked_id = other)
       or (blocker_id = other and blocked_id = auth.uid())
  );
$$;

create or replace function public.can_view_post(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.posts p
    where p.id = pid
      and (p.group_id is null or public.can_view_group(p.group_id))
      and not public.is_blocked_with(p.author_id)
  );
$$;

revoke all on function public.is_group_member(uuid) from public, anon;
revoke all on function public.can_view_group(uuid) from public, anon;
revoke all on function public.is_blocked_with(uuid) from public, anon;
revoke all on function public.can_view_post(uuid) from public, anon;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.can_view_group(uuid) to authenticated;
grant execute on function public.is_blocked_with(uuid) to authenticated;
grant execute on function public.can_view_post(uuid) to authenticated;

-- =====================================================================
-- Groups + invite codes
-- =====================================================================
alter table public.groups
  add column if not exists invite_code text unique
  default substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
alter table public.groups
  add constraint groups_invite_code_format check (invite_code is null or invite_code ~ '^[a-z0-9]{10,32}$') not valid;

-- Going private invalidates any code shared while the group was public.
create or replace function public.rotate_invite_on_private()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.is_private and not old.is_private then
    new.invite_code := substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
  end if;
  return new;
end;
$$;

drop trigger if exists groups_rotate_invite on public.groups;
create trigger groups_rotate_invite before update of is_private on public.groups
  for each row execute function public.rotate_invite_on_private();

drop policy if exists "Groups visible to members or public" on public.groups;
create policy "Groups visible to members or public" on public.groups
  for select to authenticated
  using (is_private = false or creator_id = auth.uid() or public.is_group_member(id));

drop policy if exists "Users can create groups" on public.groups;
create policy "Users can create groups" on public.groups
  for insert to authenticated
  with check (creator_id = auth.uid());

drop policy if exists "Creators update own groups" on public.groups;
create policy "Creators update own groups" on public.groups
  for update to authenticated
  using (creator_id = auth.uid())
  with check (creator_id = auth.uid());

-- =====================================================================
-- Group members: no more self-insert into private groups / self-promotion
-- =====================================================================
drop policy if exists "Group members are public" on public.group_members;
drop policy if exists "Users manage own membership" on public.group_members;

create policy "Members visible with group" on public.group_members
  for select to authenticated
  using (public.can_view_group(group_id));

create policy "Join public groups, creator joins own group as admin" on public.group_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      (role = 'member' and exists (
        select 1 from public.groups g where g.id = group_id and g.is_private = false))
      or (role = 'admin' and exists (
        select 1 from public.groups g where g.id = group_id and g.creator_id = auth.uid()))
    )
  );

create policy "Leave group or creator removes member" on public.group_members
  for delete to authenticated
  using (
    user_id = auth.uid()
    or exists (select 1 from public.groups g where g.id = group_id and g.creator_id = auth.uid())
  );

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
  where g.invite_code = lower(trim(code)) and not public.is_blocked_with(g.creator_id);
  if gid is null then
    raise exception 'Invalid invite code' using errcode = 'P0002';
  end if;
  insert into public.group_members (group_id, user_id, role)
  values (gid, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;
  return gid;
end;
$$;

revoke all on function public.join_group_with_code(text) from public, anon;
grant execute on function public.join_group_with_code(text) to authenticated;

-- =====================================================================
-- Posts
-- =====================================================================
drop policy if exists "Posts visible by visibility rules" on public.posts;
create policy "Posts visible by visibility rules" on public.posts
  for select to authenticated
  using (
    (group_id is null or public.can_view_group(group_id))
    and not public.is_blocked_with(author_id)
  );

drop policy if exists "Users create own posts" on public.posts;
create policy "Users create own posts" on public.posts
  for insert to authenticated
  with check (author_id = auth.uid() and (group_id is null or public.is_group_member(group_id)));

drop policy if exists "Users update own posts" on public.posts;
create policy "Users update own posts" on public.posts
  for update to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid() and (group_id is null or public.is_group_member(group_id)));

-- =====================================================================
-- Comments
-- =====================================================================
drop policy if exists "Comments are public" on public.comments;
create policy "Comments visible with post" on public.comments
  for select to authenticated
  using (public.can_view_post(post_id) and not public.is_blocked_with(author_id));

drop policy if exists "Users create own comments" on public.comments;
create policy "Users create own comments" on public.comments
  for insert to authenticated
  with check (author_id = auth.uid() and public.can_view_post(post_id));

-- =====================================================================
-- Likes (client must use upsert with ignoreDuplicates — no UPDATE policy)
-- =====================================================================
drop policy if exists "Likes are public" on public.likes;
drop policy if exists "Users manage own likes" on public.likes;
create policy "Likes visible with post" on public.likes
  for select to authenticated
  using (public.can_view_post(post_id) and not public.is_blocked_with(user_id));
create policy "Users like visible posts" on public.likes
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_view_post(post_id));
create policy "Users remove own likes" on public.likes
  for delete to authenticated using (user_id = auth.uid());

-- =====================================================================
-- Follows + blocking side effects
-- =====================================================================
drop policy if exists "Follows are public" on public.follows;
drop policy if exists "Users manage own follows" on public.follows;
create policy "Follows visible to signed-in users" on public.follows
  for select to authenticated using (true);
create policy "Users follow unblocked users" on public.follows
  for insert to authenticated
  with check (follower_id = auth.uid() and not public.is_blocked_with(following_id));
create policy "Users unfollow" on public.follows
  for delete to authenticated using (follower_id = auth.uid());

create or replace function public.remove_follows_on_block()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.follows
  where (follower_id = new.blocker_id and following_id = new.blocked_id)
     or (follower_id = new.blocked_id and following_id = new.blocker_id);
  return new;
end;
$$;

drop trigger if exists on_block_remove_follows on public.blocks;
create trigger on_block_remove_follows
  after insert or update on public.blocks
  for each row execute function public.remove_follows_on_block();

-- =====================================================================
-- No anonymous scraping of the social graph
-- =====================================================================
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
create policy "Profiles visible to signed-in users" on public.profiles
  for select to authenticated using (true);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "User genres are public" on public.user_genres;
create policy "User genres visible to signed-in users" on public.user_genres
  for select to authenticated using (true);

drop policy if exists "User books are public" on public.user_books;
create policy "User books visible to signed-in users" on public.user_books
  for select to authenticated using (true);

drop policy if exists "Books are public" on public.books;
create policy "Books visible to signed-in users" on public.books
  for select to authenticated using (true);

-- =====================================================================
-- Usernames: normalise legacy rows, then enforce format + case-insensitive uniqueness
-- =====================================================================
update public.profiles
set username = left(regexp_replace(lower(username), '[^a-z0-9_.]', '', 'g'), 21)
               || '_' || substr(replace(id::text, '-', ''), 1, 6)
where username !~ '^[a-z0-9_.]{3,30}$';

alter table public.profiles
  add constraint profiles_username_format check (username ~ '^[a-z0-9_.]{3,30}$');
create unique index if not exists profiles_username_lower_key on public.profiles (lower(username));

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  base text;
  candidate text;
begin
  base := lower(coalesce(
    nullif(new.raw_user_meta_data->>'username', ''),
    split_part(coalesce(new.email, ''), '@', 1)
  ));
  -- 23 + '_' + 6-char suffix = 30, the format maximum.
  base := left(regexp_replace(base, '[^a-z0-9_.]', '', 'g'), 23);
  if char_length(base) < 3 then
    base := left('leser' || base, 23);
  end if;

  -- Never fail sign-up on a taken name (Google/Apple use the e-mail local part).
  -- Random suffix, not a counter: concurrent sign-ups with the same base (and the
  -- many phone/no-email 'leser' users) neither collide on _1 nor loop through counts.
  candidate := base;
  while exists (select 1 from public.profiles where lower(username) = candidate) loop
    candidate := base || '_' || substr(md5(random()::text), 1, 6);
  end loop;

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    candidate,
    left(coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), candidate), 50)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.username_available(p_username text)
returns boolean language sql stable security definer set search_path = public as $$
  select lower(trim(p_username)) ~ '^[a-z0-9_.]{3,30}$'
    and not exists (
      select 1 from public.profiles where lower(username) = lower(trim(p_username))
    );
$$;

revoke all on function public.username_available(text) from public;
grant execute on function public.username_available(text) to anon, authenticated;

-- =====================================================================
-- Length limits (NOT VALID: legacy rows untouched, new writes enforced)
-- =====================================================================
alter table public.profiles
  add constraint profiles_display_name_len check (display_name is null or char_length(display_name) <= 50) not valid,
  add constraint profiles_bio_len check (bio is null or char_length(bio) <= 300) not valid;
alter table public.posts
  add constraint posts_content_len check (char_length(content) between 1 and 5000) not valid;
alter table public.comments
  add constraint comments_content_len check (char_length(content) between 1 and 2000) not valid;
alter table public.groups
  add constraint groups_name_len check (char_length(name) between 1 and 80) not valid,
  add constraint groups_description_len check (description is null or char_length(description) <= 500) not valid;
alter table public.group_members
  add constraint group_members_role_valid check (role in ('member', 'admin')) not valid;
alter table public.reports
  add constraint reports_reason_len check (char_length(reason) between 1 and 1000) not valid;
alter table public.books
  add constraint books_title_len check (char_length(title) <= 500) not valid,
  add constraint books_author_len check (author is null or char_length(author) <= 300) not valid,
  add constraint books_isbn_len check (isbn is null or char_length(isbn) <= 20) not valid,
  add constraint books_open_library_id_len check (open_library_id is null or char_length(open_library_id) <= 40) not valid,
  add constraint books_cover_openlibrary check (cover_url is null or cover_url like 'https://covers.openlibrary.org/%') not valid;

-- =====================================================================
-- Storage: size/type limits, no folder listing, owners can delete post images
-- =====================================================================
-- Public buckets serve public URLs without RLS; SELECT only governs listing/upsert/remove().
drop policy if exists "Avatar images are publicly accessible" on storage.objects;
drop policy if exists "Post images are publicly accessible" on storage.objects;
drop policy if exists "Users read own uploads" on storage.objects;
create policy "Users read own uploads" on storage.objects for select to authenticated
  using (bucket_id in ('avatars', 'post-images') and (storage.foldername(name))[1] = auth.uid()::text);

update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('avatars', 'post-images');

drop policy if exists "Users delete own post images" on storage.objects;
create policy "Users delete own post images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- =====================================================================
-- Account deletion moved to Edge Function `delete-account` (Storage API + admin API).
-- =====================================================================
drop function if exists public.delete_own_account();
