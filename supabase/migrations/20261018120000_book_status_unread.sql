-- 10: Shelf status "unread" (owned, not read yet). Additive: existing rows keep their status.
-- Shelf = reading | unread | read; want_to_read is the separate wishlist.
alter type public.book_status add value if not exists 'unread' before 'read';
