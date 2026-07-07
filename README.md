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
