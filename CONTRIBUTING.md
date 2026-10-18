# Arbeitsweise

Jede Änderung an Booksquad läuft so:

1. **Issue** auf GitHub anlegen (eins pro Feature, Fehler oder Aufgabe). Labels: `feature`/`bug`/`documentation`, Priorität (`prio: vor Start`, `prio: nach Start`) und Bereich (`bereich: …`).
2. **Branch** vom aktuellen `main`, benannt nach Typ, Issue-Nummer und Kurzname:
   `feature/14-regal-buchruecken`, `fix/31-login-crash`, `docs/23-release-checklist`
3. **Commits** auf diesem Branch, kleine Schritte, Nachricht nach [Conventional Commits](https://www.conventionalcommits.org/de/) (`feat:`, `fix:`, `docs:`, `chore:` …), mit Bezug aufs Issue (`(#14)`).
4. Vor jedem Commit: `flutter analyze` ohne Befunde, `flutter test` grün.
5. **Push** und **Pull Request** nach `main` mit `Closes #<nr>` in der Beschreibung. Die CI muss grün sein.
6. **Merge**, danach Branch löschen. Das Issue schließt sich automatisch.

Datenbank-Änderungen sind immer neue Migrationen in `supabase/migrations/` und nur additiv. Bestehende Nutzerdaten werden nie automatisch umbenannt oder gelöscht.

## Versionen

`version: <marketing>+<build>` in `pubspec.yaml` (z. B. `1.0.0+1`).
- Build-Nummer steigt bei jedem Store-Upload.
- Marketing-Version nach SemVer: Patch für Fehlerbehebungen, Minor für neue Features, Major für große Umbrüche.
- Jede veröffentlichte Version bekommt einen Git-Tag `v<marketing>+<build>` und einen GitHub-Release mit den geschlossenen Issues.
