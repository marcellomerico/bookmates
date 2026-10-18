# Sicherheit

## Sicherheitslücke melden

Bitte **keine öffentlichen Issues** für Sicherheitslücken. Melde sie vertraulich über
**GitHub → Security → Report a vulnerability** (private Meldung) oder per E-Mail an
`support@booksquad.de`.

Hilfreich sind: betroffene Stelle (Datei, Endpunkt, Screen), Schritte zum Nachstellen und
mögliche Auswirkungen. Du bekommst innerhalb von 7 Tagen eine Rückmeldung.

Bitte teste nur mit eigenen Konten, greife nicht auf fremde Daten zu und störe den Betrieb nicht.

## Grundsätze im Projekt

- Keine Geheimnisse im Repository: `.env`, Signatur-Schlüssel und `key.properties` sind
  ausgeschlossen. Die App enthält nur den öffentlichen Supabase-Anon-Key.
- Zugriffsschutz serverseitig: Row Level Security auf allen Tabellen, Hilfsfunktionen im nicht
  öffentlichen Schema `private`, Rate-Limits per Trigger. Regressionstest:
  `supabase/tests/rls_smoke.sql` (nur auf Entwicklungsprojekten).
- Konto-Löschung über eine Edge Function mit JWT-Prüfung; der Service-Role-Key existiert nur als
  Secret auf dem Server.
- Bilder werden vor dem Upload neu kodiert, Metadaten wie GPS werden entfernt.
