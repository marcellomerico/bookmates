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
  ('00000000-0000-4000-8000-0000000002b0', '00000000-0000-4000-8000-00000000000a', null, 'öffentlich'),
  ('00000000-0000-4000-8000-0000000002d0', '00000000-0000-4000-8000-00000000000a', null, 'moderation target'),
  ('00000000-0000-4000-8000-0000000002e0', '00000000-0000-4000-8000-00000000000a', null, 'comment target'),
  ('00000000-0000-4000-8000-0000000002f0', '00000000-0000-4000-8000-00000000000a', null, 'delete me 1'),
  ('00000000-0000-4000-8000-0000000002f1', '00000000-0000-4000-8000-00000000000a', null, 'delete me 2'),
  ('00000000-0000-4000-8000-0000000002d2', '00000000-0000-4000-8000-00000000000a', null, 'admin hide target');
insert into public.comments (post_id, author_id, content) values
  ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000a', 'geheimer kommentar');
insert into public.comments (id, post_id, author_id, content) values
  ('00000000-0000-4000-8000-0000000003e1', '00000000-0000-4000-8000-0000000002e0', '00000000-0000-4000-8000-00000000000a', 'kommentar 1'),
  ('00000000-0000-4000-8000-0000000003e2', '00000000-0000-4000-8000-0000000002e0', '00000000-0000-4000-8000-00000000000a', 'kommentar 2');
insert into public.likes (post_id, user_id) values
  ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000a');
insert into private.admins (user_id) values ('00000000-0000-4000-8000-00000000000a');

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
     or has_function_privilege('anon', 'private.is_blocked_with(uuid)', 'execute')
     or has_function_privilege('anon', 'private.can_view_post(uuid)', 'execute')
     or has_function_privilege('authenticated', 'public.handle_new_user()', 'execute') then
    raise exception 'FAIL: anon can execute private RPCs'; end if;
  -- RLS helpers must not be exposed via /rest/v1/rpc (only the public schema is).
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public'
               and p.proname in ('is_group_member', 'can_view_group', 'is_blocked_with', 'can_view_post')) then
    raise exception 'FAIL: RLS helpers still in public schema'; end if;
  if not has_function_privilege('anon', 'public.username_available(text)', 'execute') then
    raise exception 'FAIL: anon cannot check usernames'; end if;
  if (select file_size_limit from storage.buckets where id = 'post-images') is distinct from 5242880 then
    raise exception 'FAIL: post-images size limit missing'; end if;
  if has_function_privilege('anon', 'public.admin_open_reports()', 'execute')
     or has_function_privilege('anon', 'public.admin_resolve_report(uuid, text)', 'execute') then
    raise exception 'FAIL: anon can execute admin RPCs'; end if;
  if has_function_privilege('authenticated', 'private.set_report_defaults()', 'execute')
     or has_function_privilege('authenticated', 'private.enforce_rate_limit()', 'execute') then
    raise exception 'FAIL: trigger functions callable'; end if;
  if has_table_privilege('authenticated', 'private.admins', 'select') then
    raise exception 'FAIL: authenticated can read private.admins'; end if;
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

  -- first of three reports on the moderation target (before the block)
  insert into public.reports (reporter_id, post_id, reason)
  values ('00000000-0000-4000-8000-00000000000b', '00000000-0000-4000-8000-0000000002d0', 'spam');
end $$;

-- ---------------- moderation: carol + erin report -> auto-hide ----------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}', true);
insert into public.reports (reporter_id, post_id, reason)
values ('00000000-0000-4000-8000-00000000000c', '00000000-0000-4000-8000-0000000002d0', 'spam');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000e","role":"authenticated"}', true);
insert into public.reports (reporter_id, post_id, reason)
values ('00000000-0000-4000-8000-00000000000e', '00000000-0000-4000-8000-0000000002d0', 'spam');

reset role;
do $$ begin
  if (select hidden_at from public.posts where id = '00000000-0000-4000-8000-0000000002d0') is null then
    raise exception 'FAIL: post not auto-hidden after 3 reports'; end if;
  if (select count(*) from public.reports
      where post_id = '00000000-0000-4000-8000-0000000002d0' and target_type = 'post') <> 3 then
    raise exception 'FAIL: post reports lack target_type post'; end if;
end $$;
set local role authenticated;

-- as ERIN: hidden post invisible
do $$ begin
  if exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002d0') then
    raise exception 'FAIL: erin sees auto-hidden post'; end if;
end $$;

-- as CAROL: hidden post cannot be reported again (RLS check runs before the unique index;
-- the unique index itself is checked with comment reports below)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}', true);
do $$ begin
  begin
    insert into public.reports (reporter_id, post_id, reason)
    values ('00000000-0000-4000-8000-00000000000c', '00000000-0000-4000-8000-0000000002d0', 'nochmal');
    raise exception 'FAIL: carol reported the hidden post again';
  exception when insufficient_privilege then null;
  end;
end $$;

-- as ALICE (author): sees own hidden post, cannot unhide, cannot pre-hide
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$ begin
  if not exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002d0') then
    raise exception 'FAIL: author cannot see own hidden post'; end if;
  begin
    update public.posts set hidden_at = null where id = '00000000-0000-4000-8000-0000000002d0';
    raise exception 'FAIL: author unhid own post';
  exception when insufficient_privilege then null;
  end;
  insert into public.posts (id, author_id, content, hidden_at)
  values ('00000000-0000-4000-8000-0000000002d1', '00000000-0000-4000-8000-00000000000a', 'pre-hidden?', now());
  if (select hidden_at from public.posts where id = '00000000-0000-4000-8000-0000000002d1') is not null then
    raise exception 'FAIL: client-set hidden_at kept on insert'; end if;
end $$;

-- as ERIN (non-admin): admin RPCs closed
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000e","role":"authenticated"}', true);
do $$
declare rid uuid;
begin
  if (select count(*) from public.admin_open_reports()) <> 0 then
    raise exception 'FAIL: non-admin sees open reports'; end if;
  select r.id into rid from public.reports r
  where r.post_id = '00000000-0000-4000-8000-0000000002d0'
    and r.reporter_id = '00000000-0000-4000-8000-00000000000e';
  if rid is null then
    raise exception 'FAIL: erin cannot see her own report'; end if;
  begin
    perform public.admin_resolve_report(rid, 'dismiss');
    raise exception 'FAIL: non-admin resolved a report';
  exception when insufficient_privilege then null;
  end;
end $$;

-- as ALICE (admin): sees reports, dismisses -> content restored
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
declare rid uuid;
begin
  if (select count(*) from public.admin_open_reports()
      where target_post_id = '00000000-0000-4000-8000-0000000002d0') < 3 then
    raise exception 'FAIL: admin does not see the 3 open reports'; end if;
  select o.report_id into rid from public.admin_open_reports() o
  where o.target_post_id = '00000000-0000-4000-8000-0000000002d0' limit 1;
  perform public.admin_resolve_report(rid, 'dismiss');
end $$;

reset role;
do $$ begin
  if exists (select 1 from public.reports
             where post_id = '00000000-0000-4000-8000-0000000002d0' and status <> 'dismissed') then
    raise exception 'FAIL: dismiss left reports unresolved'; end if;
  if (select hidden_at from public.posts where id = '00000000-0000-4000-8000-0000000002d0') is not null then
    raise exception 'FAIL: dismiss did not restore post'; end if;
end $$;
set local role authenticated;

-- as ERIN: restored post visible again; then rate limit (10 posts / 10 min)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000e","role":"authenticated"}', true);
do $$ begin
  if not exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002d0') then
    raise exception 'FAIL: erin cannot see restored post'; end if;
  for i in 1..10 loop
    insert into public.posts (author_id, content)
    values ('00000000-0000-4000-8000-00000000000e', 'flood ' || i);
  end loop;
  begin
    insert into public.posts (author_id, content)
    values ('00000000-0000-4000-8000-00000000000e', 'flood 11');
    raise exception 'FAIL: 11th post in 10 minutes accepted';
  exception when raise_exception then
    if sqlerrm <> 'rate_limit' then raise; end if;
  end;
end $$;

-- ---------------- moderation: comment reports hide the comment, not the post ----------------
-- (the app sends post_id AND comment_id for a comment report)
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}', true);
insert into public.reports (reporter_id, reported_user_id, post_id, comment_id, reason)
values ('00000000-0000-4000-8000-00000000000c', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000002e0', '00000000-0000-4000-8000-0000000003e1', 'spam');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000e","role":"authenticated"}', true);
insert into public.reports (reporter_id, reported_user_id, post_id, comment_id, reason)
values ('00000000-0000-4000-8000-00000000000e', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000002e0', '00000000-0000-4000-8000-0000000003e1', 'spam');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000d","role":"authenticated"}', true);
insert into public.reports (reporter_id, reported_user_id, post_id, comment_id, reason)
values ('00000000-0000-4000-8000-00000000000d', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000002e0', '00000000-0000-4000-8000-0000000003e1', 'spam');

reset role;
do $$ begin
  if (select hidden_at from public.posts where id = '00000000-0000-4000-8000-0000000002e0') is not null then
    raise exception 'FAIL: comment reports hid the post'; end if;
  if (select hidden_at from public.comments where id = '00000000-0000-4000-8000-0000000003e1') is null then
    raise exception 'FAIL: comment not auto-hidden after 3 reports'; end if;
  if exists (select 1 from public.reports where comment_id = '00000000-0000-4000-8000-0000000003e1' and target_type <> 'comment') then
    raise exception 'FAIL: comment report has wrong target_type'; end if;
end $$;
set local role authenticated;

-- as CAROL: another comment under the same post is a separate target; the same one twice is not
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}', true);
do $$ begin
  insert into public.reports (reporter_id, reported_user_id, post_id, comment_id, reason)
  values ('00000000-0000-4000-8000-00000000000c', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000002e0', '00000000-0000-4000-8000-0000000003e2', 'spam');
  begin
    insert into public.reports (reporter_id, reported_user_id, post_id, comment_id, reason)
    values ('00000000-0000-4000-8000-00000000000c', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000002e0', '00000000-0000-4000-8000-0000000003e2', 'nochmal');
    raise exception 'FAIL: carol reported the same comment twice';
  exception when unique_violation then null;
  end;
end $$;
-- user-only report, used by the admin 'hide' check below
insert into public.reports (reporter_id, reported_user_id, reason)
values ('00000000-0000-4000-8000-00000000000c', '00000000-0000-4000-8000-00000000000a', 'profil');

-- as ERIN: forged moderation fields are overridden; invisible content cannot be reported
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000e","role":"authenticated"}', true);
do $$
declare st text; ts timestamptz; rb uuid;
begin
  insert into public.reports (reporter_id, post_id, reason, status, created_at, resolved_at, resolved_by)
  values ('00000000-0000-4000-8000-00000000000e', '00000000-0000-4000-8000-0000000002d2', 'forged', 'dismissed', '2000-01-01', now(), '00000000-0000-4000-8000-00000000000a');
  select status, created_at, resolved_by into st, ts, rb from public.reports
  where reporter_id = '00000000-0000-4000-8000-00000000000e' and post_id = '00000000-0000-4000-8000-0000000002d2';
  if st is distinct from 'open' or ts < now() - interval '1 minute' or rb is not null then
    raise exception 'FAIL: forged report kept (status %, created_at %, resolved_by %)', st, ts, rb; end if;
  begin
    insert into public.reports (reporter_id, post_id, reason)
    values ('00000000-0000-4000-8000-00000000000e', '00000000-0000-4000-8000-0000000002a0', 'peek');
    raise exception 'FAIL: erin reported a post she cannot see';
  exception when insufficient_privilege then null;
  end;
end $$;

-- as ALICE (admin): hide a post; 'hide' on a user-only report is rejected
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
declare rid uuid;
begin
  select o.report_id into rid from public.admin_open_reports() o where o.target_post_id = '00000000-0000-4000-8000-0000000002d2';
  if rid is null then raise exception 'FAIL: admin does not see report on hide target'; end if;
  perform public.admin_resolve_report(rid, 'hide');
  rid := null;
  select o.report_id into rid from public.admin_open_reports() o
  where o.target_user_id = '00000000-0000-4000-8000-00000000000a' and o.target_post_id is null and o.target_comment_id is null;
  if rid is null then raise exception 'FAIL: admin does not see user-only report'; end if;
  begin
    perform public.admin_resolve_report(rid, 'hide');
    raise exception 'FAIL: hide accepted on a user-only report';
  exception when invalid_parameter_value then null;
  end;
end $$;

-- as postgres: a new open report on the admin-hidden post (claims stay alice's)
reset role;
insert into public.reports (reporter_id, post_id, reason)
values ('00000000-0000-4000-8000-00000000000d', '00000000-0000-4000-8000-0000000002d2', 'nochmal');
set local role authenticated;

-- as ALICE: dismissing it must not unhide admin-hidden content
do $$
declare rid uuid;
begin
  select o.report_id into rid from public.admin_open_reports() o where o.target_post_id = '00000000-0000-4000-8000-0000000002d2';
  if rid is null then raise exception 'FAIL: admin does not see the new report'; end if;
  perform public.admin_resolve_report(rid, 'dismiss');
end $$;

reset role;
do $$ begin
  if (select hidden_at from public.posts where id = '00000000-0000-4000-8000-0000000002d2') is null then
    raise exception 'FAIL: dismiss unhid admin-hidden post'; end if;
  if (select status from public.reports where reporter_id = '00000000-0000-4000-8000-00000000000e' and post_id = '00000000-0000-4000-8000-0000000002d2') <> 'actioned' then
    raise exception 'FAIL: hide did not action the report'; end if;

  -- deleting reported content nulls post_id (set null); must not collide in unique indexes
  insert into public.reports (reporter_id, reported_user_id, post_id, reason) values
    ('00000000-0000-4000-8000-00000000000d', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000002f0', 'x'),
    ('00000000-0000-4000-8000-00000000000d', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000002f1', 'y');
  delete from public.posts where id in ('00000000-0000-4000-8000-0000000002f0', '00000000-0000-4000-8000-0000000002f1');
  if (select count(*) from public.reports
      where reporter_id = '00000000-0000-4000-8000-00000000000d' and target_type = 'post' and post_id is null) <> 2 then
    raise exception 'FAIL: reports on deleted posts not kept'; end if;
end $$;
set local role authenticated;

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
