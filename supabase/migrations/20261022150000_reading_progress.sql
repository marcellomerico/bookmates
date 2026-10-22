-- Reading progress per shelf entry (additive: existing rows stay null).
alter table public.user_books
  add column if not exists page_count int check (page_count between 1 and 20000),
  add column if not exists current_page int check (current_page >= 0);

alter table public.user_books drop constraint if exists user_books_progress_within_book;
alter table public.user_books
  add constraint user_books_progress_within_book
  check (current_page is null or page_count is null or current_page <= page_count);
