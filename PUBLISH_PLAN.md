# Booksquad — Publish-Plan

Stand: August 2026

## Im Client erledigt

- [x] Vollfunktion (keine Platzhalter-Buttons)
- [x] Passwort vergessen + Account löschen
- [x] Moderation (Melden/Blockieren)
- [x] Post-Bilder, Aktivität, private Gruppen
- [x] Support-Mail + Legal-Links im Profil
- [x] CI (GitHub Actions)
- [x] Android Release-Signing vorbereitet (`key.properties.example`)
- [x] Docs: Production, Release, OAuth, Legal-Entwürfe
- [x] Unit-Tests (Models)

## Deine Schritte vor Store-Submit

### Supabase
- [ ] Alle 3 Migrationen (`supabase/APPLY_MIGRATIONS.md`)
- [ ] Production-Projekt (`docs/SUPABASE_PRODUCTION.md`)

### Auth
- [ ] Google + Apple (`docs/GOOGLE_APPLE_AUTH.md`)
- [ ] iOS Info.plist URL Scheme mit echter Client ID

### Release
- [ ] Android Keystore + `key.properties` (`docs/RELEASE.md`)
- [ ] iOS Distribution Certificate
- [ ] `flutter build appbundle` / `flutter build ipa`

### Store
- [ ] App-Icon + Screenshots
- [ ] Legal-URLs live hosten (aktuell `getbooksquad.com` (nach Domain-Kauf))
- [ ] Datenschutz/AGB rechtlich prüfen
- [ ] Demo-Account für Apple Review

### QA
- [ ] [`TESTING.md`](TESTING.md) durchgehen
- [ ] Feedback an Entwicklung
