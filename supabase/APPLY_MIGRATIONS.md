# Supabase — Migrationen anwenden

> **Ausführliche Test-Anleitung inkl. Verifikation:** [`TESTING.md`](../TESTING.md) (Teil A + B)

## Reihenfolge

Supabase Dashboard → **SQL** → **New query**

| # | Datei | Inhalt |
|---|-------|--------|
| 1 | `20260707180000_initial_schema.sql` | Tabellen, Genres, RLS, Auth-Trigger |
| 2 | `20260731120000_storage_and_policies.sql` | Storage `avatars` + `post-images`, Delete-Policies |
| 3 | `20260731140000_moderation_and_privacy.sql` | `blocks`, `reports`, private Groups, `delete_own_account` |
| 4 | `20260731150000_fix_account_deletion.sql` | *Optional / überholt* (Migration 5 entfernt `delete_own_account`) |
| 5 | `20261016120000_security_hardening.sql` | **Pflicht:** RLS-Härtung, Invite-Codes, Username-Format, Längenlimits, Storage-Limits |
| 6 | `20261017090000_private_helpers_and_indexes.sql` | **Pflicht:** RLS-Helfer ins Schema `private` (nicht per RPC aufrufbar), Trigger-Funktionen gesperrt, Indizes für Fremdschlüssel |
| 7 | `20261017120000_moderation_and_rate_limits.sql` | **Pflicht:** Moderation (Admins in `private.admins`, ausgeblendete Inhalte, Meldungs-Status, Auto-Ausblenden ab 3 Meldungen, Admin-RPCs), Rate-Limits |
| 8 | `20261017150000_moderation_followups.sql` | **Pflicht:** Bild-URL in der Admin-Queue (Bild wird beim Löschen entfernt), Admins dürfen Post-Bilder löschen, Kommentar-Meldungen brauchen die Post-ID |
| 9 | `20261017180000_feed_indexes.sql` | Indizes für seitenweise Feeds und Like-Status |
| 10 | `20261018120000_book_status_unread.sql` | Regal-Status „ungelesen“ (rein additiv, bestehende Einträge bleiben unverändert) |

Jeweils **gesamten Dateiinhalt** kopieren → **Run**.

> **Migration 5 ist Pflicht.** Sie enthält:
> - RLS-Härtung: private Gruppen nur per Invite-Code (RPC `join_group_with_code`), Blockieren serverseitig, keine Anon-Reads
> - Username-Format (a–z, 0–9, `_`, `.`; 3–30 Zeichen) + RPC `username_available`
> - Längenlimits für Textfelder
> - Storage: max. 5 MB, nur jpeg/png/webp, Ordner-Listing nur im eigenen Ordner
> - **Entfernt** die alte RPC `delete_own_account`
>
> Migration 4 kann übersprungen werden (wird von 5 überholt).

## Edge Function: Account löschen

Account-Löschung läuft über `supabase/functions/delete-account` — **muss deployed werden** (JWT-Verifikation an):

- Dashboard → **Edge Functions** → `delete-account` deployen, oder
- `supabase functions deploy delete-account`

## RLS-Regressionstest

`supabase/tests/rls_smoke.sql` im SQL Editor ausführen — **nur auf einem DEV-Projekt, nie auf Prod**.
Erfolg = kein Fehler (letzte Zeile / Notice `ALL RLS CHECKS PASSED`); alles wird zurückgerollt.

## Auth: Redirect URLs

Dashboard → **Authentication** → **URL Configuration** → **Redirect URLs** muss `booksquad://auth-callback` enthalten (Passwort-Reset + E-Mail-Bestätigung öffnen die App).

## Schnell-Check nach Migration 5

```sql
-- 13 Tabellen?
select count(*) from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'profiles','genres','user_genres','books','user_books',
    'groups','group_members','posts','follows','likes','comments',
    'blocks','reports'
  );
-- Erwartung: 13

-- Storage?
select id from storage.buckets where id in ('avatars','post-images');
-- Erwartung: 2 Zeilen

-- Alte Lösch-RPC entfernt, neue RPCs vorhanden?
select proname from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and proname in ('delete_own_account','join_group_with_code','username_available');
-- Erwartung: 2 Zeilen (join_group_with_code, username_available), kein delete_own_account
```

## App

Terminal: **`R`** (Hot Restart) → dann [`TESTING.md`](../TESTING.md) Teil C ff.

## Admin festlegen (nach Migration 7)

Admins sehen in der App unter *Profil → Einstellungen → Meldungen prüfen* die Moderations-Queue. Gesetzt werden sie nur per SQL im Dashboard:

```sql
insert into private.admins (user_id)
select id from auth.users where email = 'deine@adresse.de';
```

## Moderations-Ablauf (Betrieb)

- **Meldungen prüfen:** in der App unter *Profil → Einstellungen → Meldungen prüfen*. Ziel ist eine Reaktion innerhalb von 24 Stunden, so steht es in den Nutzungsbedingungen.
- **Konto sperren:** im Supabase-Dashboard unter *Authentication → Users → Nutzer → „Ban user“* eine Dauer wählen (dauerhaft: sehr lange Dauer). Gesperrte Nutzer können sich nicht mehr anmelden. Inhalte bei Bedarf vorher über die Queue löschen.
- **Benachrichtigung bei neuen Meldungen (offen, braucht deinen E-Mail-Dienst):** *Database → Webhooks →* neuer Webhook auf `public.reports`, Ereignis `INSERT`, Ziel eine Edge Function oder ein Mail-Dienst (z. B. Resend) mit deinem API-Key, Empfänger die Support-Adresse. Solange das fehlt, die Queue täglich öffnen.
