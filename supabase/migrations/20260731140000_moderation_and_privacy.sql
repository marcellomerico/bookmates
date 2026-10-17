-- Moderation, privacy, account deletion

alter table public.likes
  add column if not exists created_at timestamptz not null default now();

create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid references public.profiles(id) on delete set null,
  post_id uuid references public.posts(id) on delete set null,
  comment_id uuid references public.comments(id) on delete set null,
  reason text not null,
  created_at timestamptz not null default now()
);

alter table public.blocks enable row level security;
alter table public.reports enable row level security;

create policy "Users manage own blocks"
  on public.blocks for all
  using (auth.uid() = blocker_id)
  with check (auth.uid() = blocker_id);

create policy "Users create reports"
  on public.reports for insert
  with check (auth.uid() = reporter_id);

create policy "Users view own reports"
  on public.reports for select
  using (auth.uid() = reporter_id);

-- Private groups: replace open select policy
drop policy if exists "Groups are public" on public.groups;
create policy "Groups visible to members or public"
  on public.groups for select
  using (
    is_private = false
    or creator_id = auth.uid()
    or exists (
      select 1 from public.group_members gm
      where gm.group_id = groups.id and gm.user_id = auth.uid()
    )
  );

-- Group posts visible when group is public or user is member
drop policy if exists "Posts are public" on public.posts;
create policy "Posts visible by visibility rules"
  on public.posts for select
  using (
    group_id is null
    or exists (
      select 1 from public.groups g
      where g.id = posts.group_id
        and (
          g.is_private = false
          or g.creator_id = auth.uid()
          or exists (
            select 1 from public.group_members gm
            where gm.group_id = g.id and gm.user_id = auth.uid()
          )
        )
    )
  );

-- Account deletion (Apple requirement)
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
