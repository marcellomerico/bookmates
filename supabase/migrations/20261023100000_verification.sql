-- Verification badge for known readers, authors, book blogs and bookshops (issue #11, stage 2).
-- Readers request it with a link as proof; only admins grant or revoke it.

alter table public.profiles
  add column if not exists verified_at timestamptz,
  add column if not exists verified_kind text
    check (verified_kind in ('reader', 'author', 'blog', 'bookstore'));

-- Only admins (via the RPCs below) may change the badge; everyone else keeps the old value.
create or replace function private.guard_profile_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if private.is_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.verified_at := null;
    new.verified_kind := null;
  else
    new.verified_at := old.verified_at;
    new.verified_kind := old.verified_kind;
  end if;
  return new;
end;
$$;
revoke all on function private.guard_profile_verification() from public, anon, authenticated;

drop trigger if exists profiles_guard_verification on public.profiles;
create trigger profiles_guard_verification
  before insert or update on public.profiles
  for each row execute function private.guard_profile_verification();

create table if not exists public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('reader', 'author', 'blog', 'bookstore')),
  link text not null check (char_length(link) <= 300 and link ~* '^https?://[^\s]+$'),
  note text check (note is null or char_length(note) <= 500),
  status text not null default 'open' check (status in ('open', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null
);

create unique index if not exists verification_requests_one_open
  on public.verification_requests (user_id) where status = 'open';
create index if not exists verification_requests_resolved_by_idx
  on public.verification_requests (resolved_by);

alter table public.verification_requests enable row level security;
revoke all on public.verification_requests from anon, authenticated;
grant select on public.verification_requests to authenticated;
grant insert (kind, link, note) on public.verification_requests to authenticated;

drop policy if exists "Users see own verification requests" on public.verification_requests;
create policy "Users see own verification requests" on public.verification_requests
  for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "Users request verification" on public.verification_requests;
create policy "Users request verification" on public.verification_requests
  for insert to authenticated with check (user_id = (select auth.uid()));

-- user_id defaults to the caller so the client never chooses it.
alter table public.verification_requests alter column user_id set default auth.uid();

create or replace function public.admin_open_verifications()
returns table (
  request_id uuid, requested_at timestamptz, user_id uuid, username text,
  display_name text, kind text, link text, note text
)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_admin() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
    select v.id, v.created_at, v.user_id, p.username, p.display_name, v.kind, v.link, v.note
    from public.verification_requests v
    join public.profiles p on p.id = v.user_id
    where v.status = 'open'
    order by v.created_at;
end;
$$;
revoke all on function public.admin_open_verifications() from public, anon;
grant execute on function public.admin_open_verifications() to authenticated;

create or replace function public.admin_resolve_verification(p_request_id uuid, p_approve boolean)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  req public.verification_requests;
begin
  if not private.is_admin() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.verification_requests
     set status = case when p_approve then 'approved' else 'rejected' end,
         resolved_at = now(),
         resolved_by = auth.uid()
   where id = p_request_id and status = 'open'
  returning * into req;
  if req.id is null then
    raise exception 'request not open' using errcode = 'P0002';
  end if;
  if p_approve then
    update public.profiles
       set verified_at = now(), verified_kind = req.kind
     where id = req.user_id;
  end if;
end;
$$;
revoke all on function public.admin_resolve_verification(uuid, boolean) from public, anon;
grant execute on function public.admin_resolve_verification(uuid, boolean) to authenticated;

create or replace function public.admin_revoke_verification(p_user_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.profiles set verified_at = null, verified_kind = null where id = p_user_id;
end;
$$;
revoke all on function public.admin_revoke_verification(uuid) from public, anon;
grant execute on function public.admin_revoke_verification(uuid) to authenticated;
