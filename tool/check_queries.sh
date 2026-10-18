#!/usr/bin/env bash
# Validates the app's PostgREST selects/embeds against a Supabase project using the
# public anon key from .env. RLS returns empty results for anon, but an invalid query
# (ambiguous embed, unknown column/relationship) fails with an error code.
# Usage: tool/check_queries.sh   (exit 1 if any query is invalid)
set -euo pipefail
cd "$(dirname "$0")/.."
url=$(grep '^SUPABASE_URL=' .env | cut -d= -f2-)
key=$(grep '^SUPABASE_ANON_KEY=' .env | cut -d= -f2-)
z=00000000-0000-0000-0000-000000000000
failed=0

check() {
  local code
  code=$(curl -s -o /tmp/booksquad_check.json -w '%{http_code}' "$url/rest/v1/$1" \
    -H "apikey: $key" -H "Authorization: Bearer $key")
  if [ "$code" = "200" ]; then
    echo "ok    $1"
  else
    echo "FAIL  $1 ($code: $(head -c 200 /tmp/booksquad_check.json))"
    failed=1
  fi
}

check "posts?select=*,profiles!posts_author_id_fkey(*),books(*),likes(count),comments(count)&group_id=is.null&created_at=lt.2026-01-01T00:00:00Z&order=created_at.desc&limit=20"
check "posts?select=image_url&id=eq.$z"
check "likes?select=post_id&user_id=eq.$z&post_id=in.($z)"
check "likes?select=created_at,post_id,profiles:user_id(*),posts!inner(author_id,content)&posts.author_id=eq.$z&limit=5"
check "comments?select=*,profiles(*)&post_id=eq.$z"
check "comments?select=created_at,post_id,content,profiles!comments_author_id_fkey(*),posts!inner(author_id)&posts.author_id=eq.$z&limit=5"
check "follows?select=created_at,profiles:follower_id(*)&following_id=eq.$z"
check "follows?select=profiles:following_id(*)&follower_id=eq.$z"
check "groups?select=*,profiles!creator_id(*),group_members(count)&limit=50"
check "groups?select=*,profiles!creator_id(*),group_members(user_id)&id=eq.$z"
check "group_members?select=group_id&user_id=eq.$z"
check "user_books?select=*,books(*)&user_id=eq.$z"
check "user_books?select=id&book_id=eq.$z"
check "user_genres?select=genres(name)&user_id=eq.$z"
check "books?select=*&or=(open_library_id.eq.OL1W,open_library_id.eq./works/OL1W)&limit=1"
check "genres?select=id,name"
check "posts?select=id&or=(created_at.lt.%222026-01-01T00:00:00.000Z%22,and(created_at.eq.%222026-01-01T00:00:00.000Z%22,id.lt.$z))&order=created_at.desc,id.desc&limit=20"
check "groups?select=*,profiles!creator_id(*),group_members(count)&or=(name.ilike.*krimi*,description.ilike.*krimi*)&limit=50"
check "groups?select=*,profiles!creator_id(*),group_members(count)&is_private=eq.false&genre_id=in.($z)&id=not.in.($z)&order=created_at.desc&limit=5"

exit $failed
