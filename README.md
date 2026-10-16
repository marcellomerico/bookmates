# Bookmates

Social App für Bücherfreunde — Profile, Feed, Gruppen, Bücherregal.

## Features (Client)

- Auth: E-Mail, Passwort vergessen, Account löschen, Google/Apple (Config nötig)
- Onboarding, Profil + Avatar, Bücherregal (Open Library)
- Feed, Beiträge (Text, Bild, Buch), Likes, Comments
- Folgen, Entdecken, Aktivität
- Gruppen (öffentlich/privat), Moderation (Melden/Blockieren)

## Quick Start

```bash
git clone https://github.com/<user>/bookmates.git
cd bookmates
flutter pub get
cp .env.example .env   # Supabase-Keys
flutter run
```

## Supabase

Migrationen in dieser Reihenfolge — siehe [`supabase/APPLY_MIGRATIONS.md`](supabase/APPLY_MIGRATIONS.md):

1. `20260707180000_initial_schema.sql`
2. `20260731120000_storage_and_policies.sql`
3. `20260731140000_moderation_and_privacy.sql`

## Docs

| Datei | Inhalt |
|-------|--------|
| [`TESTING.md`](TESTING.md) | Test-Checkliste |
| [`ROADMAP.md`](ROADMAP.md) | Feature-Stand |
| [`PUBLISH_PLAN.md`](PUBLISH_PLAN.md) | Store-Launch |
| [`docs/SUPABASE_PRODUCTION.md`](docs/SUPABASE_PRODUCTION.md) | Prod-Backend |
| [`docs/RELEASE.md`](docs/RELEASE.md) | Android/iOS Builds |
| [`docs/GOOGLE_APPLE_AUTH.md`](docs/GOOGLE_APPLE_AUTH.md) | OAuth Setup |
| [`docs/legal/`](docs/legal/) | Datenschutz, AGB, Impressum (Entwürfe) |

## Tech

Flutter · Riverpod · go_router · Supabase · Open Library

## CI

GitHub Actions: `flutter analyze` + `flutter test` bei Push/PR.
