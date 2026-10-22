-- Reader-defined order of books on the shelf (additive; existing rows stay null = by age).
alter table public.user_books add column if not exists shelf_position int check (shelf_position > 0);

-- Saves the whole order at once: position = place in p_ids. Runs as the caller,
-- so RLS limits it to the caller's own rows.
create or replace function public.reorder_shelf(p_ids uuid[])
returns void
language sql
security invoker
set search_path = ''
as $$
  update public.user_books
     set shelf_position = array_position(p_ids, id)
   where user_id = (select auth.uid())
     and id = any(p_ids);
$$;
revoke all on function public.reorder_shelf(uuid[]) from public, anon;
grant execute on function public.reorder_shelf(uuid[]) to authenticated;
