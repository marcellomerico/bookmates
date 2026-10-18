-- Performance only, no behavior change (Supabase advisor 0003, 0006, 0001).

-- 1) Evaluate auth.uid() once per statement instead of once per row.
do $$
declare
  p record;
  using_sql text;
  check_sql text;
begin
  for p in
    select tablename, policyname, qual, with_check
    from pg_policies
    where schemaname = 'public'
      and (coalesce(qual, '') || coalesce(with_check, '')) like '%auth.uid()%'
      and (coalesce(qual, '') || coalesce(with_check, '')) not like '%SELECT auth.uid()%'
  loop
    using_sql := case when p.qual is not null
      then format(' using (%s)', replace(p.qual, 'auth.uid()', '(select auth.uid())')) else '' end;
    check_sql := case when p.with_check is not null
      then format(' with check (%s)', replace(p.with_check, 'auth.uid()', '(select auth.uid())')) else '' end;
    execute format('alter policy %I on public.%I%s%s', p.policyname, p.tablename, using_sql, check_sql);
  end loop;
end $$;

-- 2) "Manage own" ALL policies overlapped the read-all SELECT policies. Split into writes only.
drop policy if exists "Users manage own bookshelf" on public.user_books;
create policy "Users insert own bookshelf" on public.user_books
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users update own bookshelf" on public.user_books
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users delete own bookshelf" on public.user_books
  for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users manage own genres" on public.user_genres;
create policy "Users insert own genres" on public.user_genres
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users update own genres" on public.user_genres
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users delete own genres" on public.user_genres
  for delete to authenticated using ((select auth.uid()) = user_id);

-- 3) Covering index for the moderation foreign key.
create index if not exists reports_resolved_by_idx on public.reports (resolved_by);
