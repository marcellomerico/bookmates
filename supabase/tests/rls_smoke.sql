-- RLS smoke test. Run in SQL editor or via MCP execute_sql on the DEV project.
-- Everything is rolled back. Success = no error raised (any failure raises 'FAIL ...').
-- On success it emits NOTICE and final row: ALL RLS CHECKS PASSED
begin;

-- Fixtures (as postgres: bypasses RLS)
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000000a', 'alice@rls.test', '{"username":"alice_rls"}'),
  ('00000000-0000-4000-8000-00000000000b', 'bob@rls.test',   '{"username":"bob_rls"}'),
  ('00000000-0000-4000-8000-00000000000c', 'carol@rls.test', '{"username":"Alice_RLS"}'),
  ('00000000-0000-4000-8000-00000000000d', null,             null),
  ('00000000-0000-4000-8000-00000000000e', 'erin@rls.test',  '{"username":"erinerinerinerinerinerinerinerinerinerin"}');

insert into public.groups (id, creator_id, name, is_private, invite_code) values
  ('00000000-0000-4000-8000-0000000001a0', '00000000-0000-4000-8000-00000000000a', 'Geheimzirkel', true, 'testcode01'),
  ('00000000-0000-4000-8000-0000000001b0', '00000000-0000-4000-8000-00000000000a', 'Offener Kreis', false, 'testcode02'),
  ('00000000-0000-4000-8000-0000000001c0', '00000000-0000-4000-8000-00000000000a', 'Zweiter Zirkel', true, 'testcode03');
insert into public.group_members (group_id, user_id, role) values
  ('00000000-0000-4000-8000-0000000001a0', '00000000-0000-4000-8000-00000000000a', 'admin'),
  ('00000000-0000-4000-8000-0000000001b0', '00000000-0000-4000-8000-00000000000a', 'admin'),
  ('00000000-0000-4000-8000-0000000001c0', '00000000-0000-4000-8000-00000000000a', 'admin');
insert into public.posts (id, author_id, group_id, content) values
  ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000001a0', 'geheim'),
  ('00000000-0000-4000-8000-0000000002b0', '00000000-0000-4000-8000-00000000000a', null, 'öffentlich');
insert into public.comments (post_id, author_id, content) values
  ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000a', 'geheimer kommentar');
insert into public.likes (post_id, user_id) values
  ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000a');

-- ---------------- signup trigger (as postgres) ----------------
do $$
declare
  carol_name text;
  dave_name text;
  erin_name text;
begin
  select username into carol_name from public.profiles where id = '00000000-0000-4000-8000-00000000000c';
  if carol_name is null or carol_name !~ '^alice_rls_[0-9a-f]{6}$' then
    raise exception 'FAIL trigger: got %', carol_name;
  end if;

  select username into dave_name from public.profiles where id = '00000000-0000-4000-8000-00000000000d';
  if dave_name is null or not (dave_name = 'leser' or dave_name ~ '^leser_[0-9a-f]{6}$') then
    raise exception 'FAIL trigger (no email/metadata): got %', dave_name;
  end if;

  select username into erin_name from public.profiles where id = '00000000-0000-4000-8000-00000000000e';
  if erin_name is null or char_length(erin_name) > 30 or erin_name !~ '^[a-z0-9_.]{3,30}$' then
    raise exception 'FAIL trigger (long username): got %', erin_name;
  end if;
end $$;

-- ---------------- privileges (as postgres) ----------------
do $$ begin
  if has_function_privilege('anon', 'public.join_group_with_code(text)', 'execute')
     or has_function_privilege('anon', 'public.is_blocked_with(uuid)', 'execute')
     or has_function_privilege('anon', 'public.can_view_post(uuid)', 'execute') then
    raise exception 'FAIL: anon can execute private RPCs'; end if;
  if not has_function_privilege('anon', 'public.username_available(text)', 'execute') then
    raise exception 'FAIL: anon cannot check usernames'; end if;
  if (select file_size_limit from storage.buckets where id = 'post-images') is distinct from 5242880 then
    raise exception 'FAIL: post-images size limit missing'; end if;
end $$;

-- ---------------- as BOB (outsider) ----------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);

do $$
declare n int;
begin
  if exists (select 1 from public.groups where id = '00000000-0000-4000-8000-0000000001a0') then
    raise exception 'FAIL: bob sees private group'; end if;
  if exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002a0') then
    raise exception 'FAIL: bob sees private post'; end if;
  if exists (select 1 from public.comments where post_id = '00000000-0000-4000-8000-0000000002a0') then
    raise exception 'FAIL: bob sees private comment'; end if;
  if exists (select 1 from public.likes where post_id = '00000000-0000-4000-8000-0000000002a0') then
    raise exception 'FAIL: bob sees private like'; end if;
  if exists (select 1 from public.group_members where group_id = '00000000-0000-4000-8000-0000000001a0') then
    raise exception 'FAIL: bob sees private members'; end if;

  begin
    insert into public.group_members (group_id, user_id, role)
    values ('00000000-0000-4000-8000-0000000001a0', '00000000-0000-4000-8000-00000000000b', 'member');
    raise exception 'FAIL: bob self-joined private group';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.group_members (group_id, user_id, role)
    values ('00000000-0000-4000-8000-0000000001b0', '00000000-0000-4000-8000-00000000000b', 'admin');
    raise exception 'FAIL: bob joined public group as admin';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.posts (author_id, group_id, content)
    values ('00000000-0000-4000-8000-00000000000b', '00000000-0000-4000-8000-0000000001a0', 'spam');
    raise exception 'FAIL: bob posted into private group';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.comments (post_id, author_id, content)
    values ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000b', 'spam');
    raise exception 'FAIL: bob commented on invisible post';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.posts (author_id, content)
    values ('00000000-0000-4000-8000-00000000000b', repeat('x', 5001));
    raise exception 'FAIL: oversized post accepted';
  exception when check_violation then null;
  end;

  -- allowed: own public post; moving it into the private group is not
  insert into public.posts (id, author_id, group_id, content)
  values ('00000000-0000-4000-8000-0000000002c0', '00000000-0000-4000-8000-00000000000b', null, 'bobs beitrag');
  begin
    update public.posts set group_id = '00000000-0000-4000-8000-0000000001a0'
    where id = '00000000-0000-4000-8000-0000000002c0';
    raise exception 'FAIL: bob moved his post into private group';
  exception when insufficient_privilege then null;
  end;

  -- allowed: join public group as member
  insert into public.group_members (group_id, user_id, role)
  values ('00000000-0000-4000-8000-0000000001b0', '00000000-0000-4000-8000-00000000000b', 'member');

  -- no UPDATE policy: self-promotion silently affects 0 rows
  update public.group_members set role = 'admin'
  where group_id = '00000000-0000-4000-8000-0000000001b0' and user_id = '00000000-0000-4000-8000-00000000000b';
  if exists (select 1 from public.group_members
             where group_id = '00000000-0000-4000-8000-0000000001b0'
               and user_id = '00000000-0000-4000-8000-00000000000b' and role = 'admin') then
    raise exception 'FAIL: bob promoted himself to admin'; end if;

  delete from public.group_members
  where group_id = '00000000-0000-4000-8000-0000000001b0' and user_id = '00000000-0000-4000-8000-00000000000a';
  get diagnostics n = row_count;
  if n <> 0 then
    raise exception 'FAIL: bob removed alice from group (% rows)', n; end if;

  begin
    perform public.join_group_with_code('nope000000');
    raise exception 'FAIL: invalid invite code accepted';
  exception when no_data_found then null;
  end;

  -- allowed: join private group via invite code (case-insensitive)
  if public.join_group_with_code(' TESTCODE01 ') <> '00000000-0000-4000-8000-0000000001a0' then
    raise exception 'FAIL: invite join returned wrong group'; end if;
  if not exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002a0') then
    raise exception 'FAIL: member cannot see private post after invite'; end if;

  if public.username_available('ALICE_rls') then
    raise exception 'FAIL: username_available is case-sensitive'; end if;

  begin
    update public.profiles set username = 'Bad Name' where id = '00000000-0000-4000-8000-00000000000b';
    raise exception 'FAIL: invalid username accepted';
  exception when check_violation then null;
  end;

  begin
    update public.profiles set username = 'alice_rls' where id = '00000000-0000-4000-8000-00000000000b';
    raise exception 'FAIL: duplicate username accepted';
  exception when unique_violation then null;
  end;

  -- allowed (before the block): comment on and like alice's public post
  insert into public.comments (post_id, author_id, content)
  values ('00000000-0000-4000-8000-0000000002b0', '00000000-0000-4000-8000-00000000000b', 'bobs kommentar');
  insert into public.likes (post_id, user_id)
  values ('00000000-0000-4000-8000-0000000002b0', '00000000-0000-4000-8000-00000000000b');
end $$;

-- ---------------- as ALICE: follow, then block bob ----------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
begin
  insert into public.follows (follower_id, following_id)
  values ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-00000000000b');
  insert into public.blocks (blocker_id, blocked_id)
  values ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-00000000000b');
  if exists (select 1 from public.follows
             where follower_id = '00000000-0000-4000-8000-00000000000a'
               and following_id = '00000000-0000-4000-8000-00000000000b') then
    raise exception 'FAIL: follow survived block'; end if;
end $$;

-- ---------------- as BOB (blocked) ----------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);
do $$
begin
  if exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002b0') then
    raise exception 'FAIL: blocked bob sees alice post'; end if;
  begin
    insert into public.follows (follower_id, following_id)
    values ('00000000-0000-4000-8000-00000000000b', '00000000-0000-4000-8000-00000000000a');
    raise exception 'FAIL: blocked bob followed alice';
  exception when insufficient_privilege then null;
  end;
  -- RLS WITH CHECK runs before the PK check, so the earlier like does not matter here
  begin
    insert into public.likes (post_id, user_id)
    values ('00000000-0000-4000-8000-0000000002b0', '00000000-0000-4000-8000-00000000000b');
    raise exception 'FAIL: blocked bob liked alice post';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.comments (post_id, author_id, content)
    values ('00000000-0000-4000-8000-0000000002b0', '00000000-0000-4000-8000-00000000000b', 'noch einer');
    raise exception 'FAIL: blocked bob commented on alice post';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.join_group_with_code('testcode03');
    raise exception 'FAIL: blocked bob joined alice group via invite code';
  exception when no_data_found then null;
  end;
end $$;

-- ---------------- as ALICE (blocker) ----------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
begin
  if exists (select 1 from public.comments
             where post_id = '00000000-0000-4000-8000-0000000002b0'
               and author_id = '00000000-0000-4000-8000-00000000000b') then
    raise exception 'FAIL: alice sees blocked bob comment'; end if;
  if exists (select 1 from public.posts where author_id = '00000000-0000-4000-8000-00000000000b') then
    raise exception 'FAIL: alice sees blocked bob posts'; end if;
  if exists (select 1 from public.likes where user_id = '00000000-0000-4000-8000-00000000000b') then
    raise exception 'FAIL: alice sees blocked bob likes'; end if;

  update public.groups set is_private = true where id = '00000000-0000-4000-8000-0000000001b0';
  if coalesce((select invite_code from public.groups where id = '00000000-0000-4000-8000-0000000001b0'), 'testcode02') = 'testcode02' then
    raise exception 'FAIL: invite code not rotated when group went private'; end if;
end $$;

-- ---------------- as ANON ----------------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if exists (select 1 from public.profiles) then
    raise exception 'FAIL: anon reads profiles'; end if;
  if exists (select 1 from public.posts) then
    raise exception 'FAIL: anon reads posts'; end if;
  if exists (select 1 from public.groups) then
    raise exception 'FAIL: anon reads groups'; end if;
  if exists (select 1 from public.comments) then
    raise exception 'FAIL: anon reads comments'; end if;
  if exists (select 1 from public.likes) then
    raise exception 'FAIL: anon reads likes'; end if;
  if exists (select 1 from public.follows) then
    raise exception 'FAIL: anon reads follows'; end if;
  if exists (select 1 from public.group_members) then
    raise exception 'FAIL: anon reads group members'; end if;
  if exists (select 1 from public.user_books) then
    raise exception 'FAIL: anon reads user books'; end if;
  if exists (select 1 from public.books) then
    raise exception 'FAIL: anon reads books'; end if;
  if not public.username_available('niemand_hier_123') then
    raise exception 'FAIL: anon cannot check username availability'; end if;
  if public.username_available('ab') then
    raise exception 'FAIL: username_available ignores format'; end if;
end $$;

do $$ begin raise notice 'ALL RLS CHECKS PASSED'; end $$;
select 'ALL RLS CHECKS PASSED' as result;
rollback;
