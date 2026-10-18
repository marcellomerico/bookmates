-- Same rule as before (signed-in users may add books), without auth.role() per row (advisor 0003).
drop policy if exists "Authenticated users can insert books" on public.books;
create policy "Authenticated users can insert books" on public.books
  for insert to authenticated with check (true);
