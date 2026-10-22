-- Shelf status "abandoned" (owned, stopped reading). Additive: existing rows keep their status.
alter type public.book_status add value if not exists 'abandoned' after 'read';
