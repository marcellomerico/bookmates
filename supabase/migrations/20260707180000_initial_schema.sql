-- Profiles
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  bio text,
  avatar_url text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now()
);

-- Genres
create table if not exists public.genres (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  slug text unique not null
);

insert into public.genres (name, slug) values
  ('Fantasy', 'fantasy'),
  ('Science Fiction', 'science-fiction'),
  ('Krimi', 'krimi'),
  ('Thriller', 'thriller'),
  ('Romance', 'romance'),
  ('Historisch', 'historisch'),
  ('Biografie', 'biografie'),
  ('Sachbuch', 'sachbuch'),
  ('Young Adult', 'young-adult'),
  ('Horror', 'horror'),
  ('Klassiker', 'klassiker'),
  ('Poetry', 'poetry'),
  ('Graphic Novel', 'graphic-novel'),
  ('Self-Help', 'self-help'),
  ('Philosophie', 'philosophie')
on conflict (name) do nothing;

create table if not exists public.user_genres (
  user_id uuid not null references public.profiles(id) on delete cascade,
  genre_id uuid not null references public.genres(id) on delete cascade,
  primary key (user_id, genre_id)
);

-- Books cache
create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  open_library_id text unique,
  title text not null,
  author text,
  cover_url text,
  isbn text,
  created_at timestamptz not null default now()
);

create type public.book_status as enum ('reading', 'read', 'want_to_read');

create table if not exists public.user_books (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  status public.book_status not null default 'want_to_read',
  rating int check (rating between 1 and 5),
  unique (user_id, book_id)
);

create type public.post_type as enum ('review', 'recommendation', 'discussion', 'quote');

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  genre_id uuid references public.genres(id) on delete set null,
  is_private boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  primary key (group_id, user_id)
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  book_id uuid references public.books(id) on delete set null,
  group_id uuid references public.groups(id) on delete cascade,
  content text not null,
  post_type public.post_type not null default 'discussion',
  image_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (post_id, user_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.user_genres enable row level security;
alter table public.books enable row level security;
alter table public.user_books enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.posts enable row level security;
alter table public.follows enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.genres enable row level security;

create policy "Profiles are viewable by everyone" on public.profiles for select using (true);
create policy "Users can update own profile" on public.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles for insert with check (auth.uid() = id);

create policy "Genres are public" on public.genres for select using (true);

create policy "User genres are public" on public.user_genres for select using (true);
create policy "Users manage own genres" on public.user_genres for all using (auth.uid() = user_id);

create policy "Books are public" on public.books for select using (true);
create policy "Authenticated users can insert books" on public.books for insert with check (auth.role() = 'authenticated');

create policy "User books are public" on public.user_books for select using (true);
create policy "Users manage own bookshelf" on public.user_books for all using (auth.uid() = user_id);

create policy "Groups are public" on public.groups for select using (true);
create policy "Users can create groups" on public.groups for insert with check (auth.uid() = creator_id);

create policy "Group members are public" on public.group_members for select using (true);
create policy "Users manage own membership" on public.group_members for all using (auth.uid() = user_id);

create policy "Posts are public" on public.posts for select using (true);
create policy "Users create own posts" on public.posts for insert with check (auth.uid() = author_id);
create policy "Users update own posts" on public.posts for update using (auth.uid() = author_id);

create policy "Follows are public" on public.follows for select using (true);
create policy "Users manage own follows" on public.follows for all using (auth.uid() = follower_id);

create policy "Likes are public" on public.likes for select using (true);
create policy "Users manage own likes" on public.likes for all using (auth.uid() = user_id);

create policy "Comments are public" on public.comments for select using (true);
create policy "Users create own comments" on public.comments for insert with check (auth.uid() = author_id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
