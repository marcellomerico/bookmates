# Bookmates

Social Media App für Bücherfreunde — connecten nach Genre, Interessen und Leselisten.

## Vision

Leser können:
- Profile mit Lieblingsgenres und Bücherregalen pflegen
- Beiträge teilen (Rezensionen, Empfehlungen, Diskussionen)
- anderen Lesern folgen und einen personalisierten Feed sehen
- Gruppen nach Genre oder Thema erstellen und beitreten
- neue Leser mit ähnlichen Interessen entdecken

## Tech-Stack

| Schicht | Technologie |
|---------|-------------|
| Mobile | Flutter (iOS + Android) |
| State Management | Riverpod |
| Navigation | go_router |
| Backend | Supabase (Auth, Postgres, Realtime, Storage) |
| Buchdaten | Open Library API |

## Voraussetzungen

- Flutter SDK 3.x
- Xcode (für iOS)
- Android Studio (für Android)
- Supabase-Konto

```bash
flutter doctor
```

## Setup

```bash
git clone https://github.com/<dein-user>/bookmates.git
cd bookmates
flutter pub get
cp .env.example .env   # Supabase-Keys eintragen
flutter run
```

## Projektstruktur

```
bookmates/
├── lib/           # Flutter App-Code
├── supabase/      # DB-Migrationen
├── android/
├── ios/
└── pubspec.yaml
```

## Status

🚧 In Entwicklung — Phase 0: Repository & Entwicklungsumgebung

## Phase 1 – Aktueller Stand

- Flutter-Projekt mit iOS + Android
- Riverpod, go_router, supabase_flutter
- Auth-Screens (Login, Register, Onboarding)
- Main Shell mit 5 Tabs (Home, Entdecken, Post, Gruppen, Profil)
- Supabase SQL-Migration unter `supabase/migrations/`

### App starten

```bash
cd ~/Developer/bookmates
flutter pub get
flutter run
```

### Supabase einrichten

1. Projekt auf [supabase.com](https://supabase.com) erstellen
2. SQL aus `supabase/migrations/20260707180000_initial_schema.sql` im SQL Editor ausführen
3. URL + Anon Key in `.env` eintragen
4. App neu starten
