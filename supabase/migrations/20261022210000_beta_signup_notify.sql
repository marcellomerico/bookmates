-- Mail notice for each beta sign-up: an AFTER INSERT trigger calls the Edge Function
-- beta-signup-notify via pg_net. Function URL and anon key come from Vault
-- (secrets 'beta_notify_url', 'beta_notify_key'); without them the trigger does nothing.
create extension if not exists pg_net;

alter table public.beta_signups add column if not exists notified_at timestamptz;

create or replace function private.notify_beta_signup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  fn_url text := (select decrypted_secret from vault.decrypted_secrets where name = 'beta_notify_url');
  fn_key text := (select decrypted_secret from vault.decrypted_secrets where name = 'beta_notify_key');
begin
  if fn_url is not null and fn_key is not null then
    perform net.http_post(
      url := fn_url,
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || fn_key),
      body := jsonb_build_object('id', new.id)
    );
  end if;
  return new;
end;
$$;
revoke all on function private.notify_beta_signup() from public, anon, authenticated;

drop trigger if exists beta_signups_notify on public.beta_signups;
create trigger beta_signups_notify
  after insert on public.beta_signups
  for each row execute function private.notify_beta_signup();
