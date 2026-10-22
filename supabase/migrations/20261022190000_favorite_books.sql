-- Up to three favourite books per reader, shown on the profile (additive: existing rows stay null).
alter table public.user_books
  add column if not exists favorite_rank smallint check (favorite_rank between 1 and 3);

create unique index if not exists user_books_favorite_rank_key
  on public.user_books (user_id, favorite_rank)
  where favorite_rank is not null;
