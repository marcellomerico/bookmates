-- Shelf decoration (plants & co.) placed by the reader on their boards (additive).
-- Stored on the profile: [{"i": item, "r": board, "s": slot}], max 16 pieces.
create or replace function private.valid_shelf_decor(d jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(d) = 'array'
     and jsonb_array_length(d) <= 16
     and not exists (
       select 1 from jsonb_array_elements(d) e
       where jsonb_typeof(e) <> 'object'
          or (e ->> 'i') is null
          or (e ->> 'i') not in ('plant', 'cactus', 'flowers', 'candle', 'mug', 'cat',
                                 'teddy', 'trophy', 'picture', 'hourglass', 'globe', 'camera')
          or jsonb_typeof(e -> 'r') <> 'number' or (e ->> 'r')::int not between 0 and 49
          or jsonb_typeof(e -> 's') <> 'number' or (e ->> 's')::int not between 0 and 5
     );
$$;

alter table public.profiles
  add column if not exists shelf_decor jsonb not null default '[]'::jsonb;

alter table public.profiles drop constraint if exists profiles_shelf_decor_valid;
alter table public.profiles
  add constraint profiles_shelf_decor_valid check (private.valid_shelf_decor(shelf_decor));
