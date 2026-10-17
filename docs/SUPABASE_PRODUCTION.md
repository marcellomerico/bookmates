# Supabase Production Setup

## 1. Projekt

- Eigenes **Production-Projekt** auf [supabase.com](https://supabase.com) anlegen
- Dev- und Prod-Keys getrennt halten (`.env` lokal, Secrets in CI)

## 2. Migrationen (Reihenfolge)

Im SQL Editor ausführen:

1. `supabase/migrations/20260707180000_initial_schema.sql`
2. `supabase/migrations/20260731120000_storage_and_policies.sql`
3. `supabase/migrations/20260731140000_moderation_and_privacy.sql`
4. `supabase/migrations/20260731150000_fix_account_deletion.sql` (optional, von 5 überholt)
5. `supabase/migrations/20261016120000_security_hardening.sql`
6. `supabase/migrations/20261017090000_private_helpers_and_indexes.sql`

Danach Edge Function deployen (JWT-Verifikation an): `supabase functions deploy delete-account` oder Dashboard → Edge Functions.

> `supabase/tests/rls_smoke.sql` **nie auf Prod** ausführen — nur auf einem DEV-Projekt.

## 3. Auth

- **Site URL:** deine App-URL oder `bookmates://` Deep Link
- **Redirect URLs:** iOS/Android OAuth Callbacks + `bookmates://auth-callback` (Passwort-Reset, E-Mail-Bestätigung)
- **E-Mail:** Bestätigung aktivieren + Template anpassen
- **Google Provider:** Web Client ID + Secret
- **Apple Provider:** Service ID + Key

## 4. Storage

Buckets prüfen: `avatars`, `post-images` (public read, authed write; max. 5 MB, jpeg/png/webp; Listing nur im eigenen Ordner)

## 5. Sicherheit

- RLS auf allen Tabellen aktiv lassen
- Anon Key nur im Client; Service Role **nie** in der App
- Rate Limits im Dashboard prüfen

## 6. Backup

- Point-in-Time Recovery (Pro Plan) oder regelmäßige DB-Exports
