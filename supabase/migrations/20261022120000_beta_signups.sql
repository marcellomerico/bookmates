-- Beta tester sign-ups from booksquad.de. The website (anon key) may only insert;
-- nobody reads via the API. The owner exports via dashboard/SQL.
create table if not exists public.beta_signups (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  first_name text check (first_name is null or char_length(first_name) between 1 and 60),
  email text not null check (char_length(email) <= 254 and email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  platform text not null check (platform in ('ios', 'android')),
  consent boolean not null check (consent)
);

create unique index if not exists beta_signups_email_key on public.beta_signups (lower(email));

alter table public.beta_signups enable row level security;

revoke all on public.beta_signups from anon, authenticated;
grant insert (first_name, email, platform, consent) on public.beta_signups to anon;

drop policy if exists "Website can add beta sign-ups" on public.beta_signups;
create policy "Website can add beta sign-ups" on public.beta_signups
  for insert to anon with check (consent);

-- Spam brake: at most 30 sign-ups per 10 minutes overall.
create or replace function private.limit_beta_signups()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.beta_signups where created_at > now() - interval '10 minutes') >= 30 then
    raise exception 'rate_limit';
  end if;
  return new;
end;
$$;
revoke all on function private.limit_beta_signups() from public, anon, authenticated;

drop trigger if exists beta_signups_rate_limit on public.beta_signups;
create trigger beta_signups_rate_limit
  before insert on public.beta_signups
  for each row execute function private.limit_beta_signups();
