-- "Kein Interesse" on book suggestions, so a dismissed book never comes back (additive).
create table if not exists public.book_dismissals (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  open_library_id text not null check (char_length(open_library_id) <= 40),
  created_at timestamptz not null default now(),
  primary key (user_id, open_library_id)
);

alter table public.book_dismissals enable row level security;
revoke all on public.book_dismissals from anon, authenticated;
grant select, delete on public.book_dismissals to authenticated;
grant insert (open_library_id) on public.book_dismissals to authenticated;

drop policy if exists "Users read own dismissals" on public.book_dismissals;
create policy "Users read own dismissals" on public.book_dismissals
  for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "Users add own dismissals" on public.book_dismissals;
create policy "Users add own dismissals" on public.book_dismissals
  for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "Users remove own dismissals" on public.book_dismissals;
create policy "Users remove own dismissals" on public.book_dismissals
  for delete to authenticated using (user_id = (select auth.uid()));
