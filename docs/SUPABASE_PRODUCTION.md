# Supabase Production Setup

## 1. Projekt

- Eigenes **Production-Projekt** auf [supabase.com](https://supabase.com) anlegen
- Dev- und Prod-Keys getrennt halten (`.env` lokal, Secrets in CI)

## 2. Migrationen (Reihenfolge)

Im SQL Editor ausführen:

1. `supabase/migrations/20260707180000_initial_schema.sql`
2. `supabase/migrations/20260731120000_storage_and_policies.sql`
3. `supabase/migrations/20260731140000_moderation_and_privacy.sql`

## 3. Auth

- **Site URL:** deine App-URL oder `bookmates://` Deep Link
- **Redirect URLs:** iOS/Android OAuth Callbacks
- **E-Mail:** Bestätigung aktivieren + Template anpassen
- **Google Provider:** Web Client ID + Secret
- **Apple Provider:** Service ID + Key

## 4. Storage

Buckets prüfen: `avatars`, `post-images` (public read, authed write)

## 5. Sicherheit

- RLS auf allen Tabellen aktiv lassen
- Anon Key nur im Client; Service Role **nie** in der App
- Rate Limits im Dashboard prüfen

## 6. Backup

- Point-in-Time Recovery (Pro Plan) oder regelmäßige DB-Exports
