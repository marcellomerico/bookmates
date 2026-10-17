-- Indexes for paginated feeds and liked-by-me lookups.
-- user_books(book_id) already exists as user_books_book_id_idx (20261017090000).
create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists posts_group_created_idx on public.posts (group_id, created_at desc);
create index if not exists posts_book_created_idx on public.posts (book_id, created_at desc);
create index if not exists likes_user_post_idx on public.likes (user_id, post_id);
