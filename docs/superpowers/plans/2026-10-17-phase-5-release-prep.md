# Phase 5 — Release-Vorbereitung: Plan

**Goal:** Die App ist technisch einreichungsbereit:
- eigenes App-Icon und eigener Splash
- nachvollziehbare Versionierung
- reproduzierbarer Release-Build
- Produktions-Backend vorbereitet
- Store-Texte fertig

Was Konten, Geld, Zugangsdaten oder rechtliche Verantwortung braucht, steht gesammelt in `docs/RELEASE_CHECKLIST.md` (Marcellos Aufgaben).

## Tasks

### 1 — App-Icon & Splash (Claude)
- [ ] Icon-Motif als Code (`tool/branding/render_branding_test.dart`, `CustomPainter`): stilisiertes offenes Buch in Creme mit goldenem Lesezeichen auf Bordeaux. Ausgabe:
  - `assets/branding/icon.png` (1024², vollflächig, ohne Transparenz, iOS)
  - `icon_foreground.png` (1024², transparent, Motiv in der Safe Zone, Android adaptive)
  - `splash.png` (Motiv für den Splash)
  Ein Austausch gegen ein Designer-Icon ist später ein Datei-Tausch plus Generator-Lauf.
- [ ] `flutter_launcher_icons` + `flutter_native_splash` als dev_dependencies mit Konfiguration in `pubspec.yaml`. Icons generieren (iOS alle Größen, Android mipmaps plus adaptive Icon mit Hintergrund `#7B3140`). Splash: Creme `#F7F2E8` mit Motiv, Android-12-Splash-API inklusive.
- [ ] Android-Label „Bookmates“ (bereits gesetzt), iOS `CFBundleDisplayName` „Bookmates“ (gesetzt) prüfen.

### 2 — Versionierung & Build (Claude)
- [ ] Schema: `version: <marketing>+<build>` in pubspec. Der Build steigt bei jedem Store-Upload, die Marketing-Version folgt SemVer. Erste Einreichung `1.0.0+1`.
- [ ] `tool/build_release.sh <android|ios> [build-number]`:
  - prüft analyze und test sowie die Abfragen über `tool/check_queries.sh`
  - prüft, dass `.env` auf das Prod-Projekt zeigt (Projekt-Ref per `BOOKMATES_PROD_REF` übergeben) und `android/key.properties` vorhanden ist (Android)
  - baut `flutter build appbundle` bzw. `flutter build ipa` mit `--build-number`
- [ ] iOS `Info.plist`: `ITSAppUsesNonExemptEncryption = false` (nur Standard-HTTPS). Dann entfällt die Export-Frage bei jedem Upload.
- [ ] Android: `minifyEnabled`/R8 ist Flutter-Default; `targetSdk` folgt dem Flutter-Default (entspricht der Play-Anforderung 2026). Prüfen.

### 3 — Produktions-Backend vorbereiten (Claude, ohne Kosten auszulösen)
- [ ] `supabase/prod_setup.sql`: alle Pflicht-Migrationen in Reihenfolge (1, 2, 3, 5, 6, 7, 8, 9) als eine Datei, per Generator `tool/build_prod_setup.sh` erzeugt (keine Handpflege).
- [ ] `docs/SUPABASE_PRODUCTION.md` aktualisieren:
  - Region Frankfurt, Pro-Plan, AVV
  - Auth-Einstellungen (E-Mail-Bestätigung an, Redirect-URL, Leaked-Password-Schutz, Rate-Limits/CAPTCHA)
  - Edge Function deployen, Admin setzen, RLS-Test (nur Dev!), `.env` für Release-Builds
- [ ] Anlage des Prod-Projekts: Das löst Kosten aus, deshalb entscheidet Marcello. Danach kann Claude Migrationen, Function und Checks per MCP einspielen.

### 4 — Store-Texte (Claude)
- [ ] `docs/STORE_LISTING.md` (Deutsch):
  - App Store: Name, Untertitel (≤ 30), Werbetext (≤ 170), Beschreibung (≤ 4000), Keywords (≤ 100), Neuerungen
  - Play: Titel (≤ 30), Kurzbeschreibung (≤ 80), Beschreibung (≤ 4000)
  - Kategorien, Kontakt, Screenshot-Plan (welche Screens, Reihenfolge, Bildtexte)
  - Zeichenlimits per Skript geprüft

### 5 — Release-Checkliste (Claude schreibt, Marcello erledigt)
- [ ] `docs/RELEASE_CHECKLIST.md`: alle manuellen Schritte in Reihenfolge, mit Links auf die passenden Docs.
- [ ] TestFlight und Play Internal Testing: genaue Schritte.

### 6 — Abschluss
- [ ] Build-Checks (iOS-Simulator, Android-Debug), Icon und Splash im Simulator ansehen
- [ ] PR `phase-5/release-prep` → `main`
