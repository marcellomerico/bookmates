-- 11: Least privilege for client roles. Removes table privileges the app never uses.
-- RLS already blocks these paths; TRUNCATE in particular bypasses RLS, so it must not be
-- grantable to API roles at all. No data is changed.

-- Never needed by the API roles.
revoke truncate, trigger, references on all tables in schema public from anon, authenticated;
-- Signed-out clients only read (genres) and call username_available; they never write.
revoke insert, update, delete on all tables in schema public from anon;

-- Same for tables created by later migrations.
alter default privileges for role postgres in schema public
  revoke truncate, trigger, references on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke insert, update, delete on tables from anon;
