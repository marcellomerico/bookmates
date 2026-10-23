-- Reading streak and yearly goal for the new Home (issue #90).
-- Reading days are logged server-side whenever progress moves forward or a book is finished,
-- so every client gets the same streak. Additive: existing rows keep finished_at = null.

alter table public.profiles
  add column if not exists reading_goal smallint check (reading_goal between 1 and 365);

alter table public.user_books
  add column if not exists finished_at timestamptz;

create table if not exists public.reading_days (
  user_id uuid not null references public.profiles(id) on delete cascade,
  day date not null,
  pages integer not null default 0 check (pages >= 0),
  primary key (user_id, day)
);

-- Streaks are private: only the reader sees their own days. Writes come from the trigger.
alter table public.reading_days enable row level security;
revoke all on public.reading_days from anon, authenticated;
grant select on public.reading_days to authenticated;

drop policy if exists "Users read own reading days" on public.reading_days;
create policy "Users read own reading days" on public.reading_days
  for select to authenticated using (user_id = (select auth.uid()));

-- shortcut: days are counted in German time (the app's only locale); per-user time zones if we go abroad.
create or replace function private.berlin_today()
returns date language sql stable set search_path = '' as $$
  select (now() at time zone 'Europe/Berlin')::date;
$$;
revoke all on function private.berlin_today() from public, anon;
grant execute on function private.berlin_today() to authenticated;

create or replace function private.log_reading_day()
returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  delta integer := 0;
  finished boolean := new.status = 'read' and (tg_op = 'INSERT' or old.status is distinct from 'read');
begin
  if tg_op = 'UPDATE' then
    delta := greatest(coalesce(new.current_page, 0) - coalesce(old.current_page, 0), 0);
  end if;
  if finished then
    new.finished_at := coalesce(new.finished_at, now());
  elsif new.status is distinct from 'read' then
    new.finished_at := null;
  end if;
  if delta > 0 or finished then
    insert into public.reading_days (user_id, day, pages)
      values (new.user_id, private.berlin_today(), delta)
      on conflict (user_id, day) do update
        set pages = public.reading_days.pages + excluded.pages;
  end if;
  return new;
end;
$$;
revoke all on function private.log_reading_day() from public, anon, authenticated;

drop trigger if exists user_books_log_reading_day on public.user_books;
create trigger user_books_log_reading_day
  before insert or update of current_page, status on public.user_books
  for each row execute function private.log_reading_day();

-- Home numbers for the caller: streak (ending today or yesterday), the last 7 days
-- (oldest first), books finished this year and the goal.
create or replace function public.my_reading_stats()
returns table (streak integer, week boolean[], finished_this_year integer, goal smallint)
language plpgsql stable security invoker set search_path = '' as $$
declare
  me uuid := auth.uid();
  today date := private.berlin_today();
  d date;
  n integer := 0;
begin
  d := case
    when exists (select 1 from public.reading_days where user_id = me and day = today) then today
    else today - 1
  end;
  while exists (select 1 from public.reading_days where user_id = me and day = d) loop
    n := n + 1;
    d := d - 1;
  end loop;
  return query select
    n,
    array(
      select exists (select 1 from public.reading_days r where r.user_id = me and r.day = g::date)
      from generate_series(today - 6, today, interval '1 day') g order by g
    ),
    (select count(*)::integer from public.user_books
      where user_id = me and status = 'read'
        and finished_at >= date_trunc('year', now() at time zone 'Europe/Berlin') at time zone 'Europe/Berlin'),
    (select p.reading_goal from public.profiles p where p.id = me);
end;
$$;
revoke all on function public.my_reading_stats() from public, anon;
grant execute on function public.my_reading_stats() to authenticated;
