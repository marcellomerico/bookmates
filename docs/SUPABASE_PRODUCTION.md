# Supabase Production Setup

Reihenfolge einhalten. Schritte mit **(automatisierbar)** lassen sich per Supabase CLI oder MCP erledigen, sobald das Projekt existiert.

## 1. Projekt anlegen (Dashboard, kostenpflichtiger Plan)

- Neues Projekt, Region **Frankfurt (eu-central-1)**, Plan **Pro** (tägliche Backups, kein Pausieren bei Inaktivität)
- Datenbank-Passwort im Passwort-Manager speichern
- **AVV/DPA** mit Supabase abschließen (Dashboard → Organization → Legal Documents)
- Dev- und Prod-Keys getrennt halten. Die App liest `.env`, Release-Builds brauchen die **Prod**-Werte (siehe `docs/RELEASE.md`)

## 2. Schema einspielen (automatisierbar oder SQL Editor)

`supabase/prod_setup.sql` enthält alle Pflicht-Migrationen in Reihenfolge, in **einer** Transaktion (alles oder nichts). Erzeugt von `tool/build_prod_setup.sh`; nach jeder neuen Migration neu erzeugen und committen.

- SQL Editor → New query → gesamten Inhalt von `supabase/prod_setup.sql` → Run, **oder**
- Die Migrationen einzeln per CLI/MCP anwenden (`apply_migration`), damit sie in der Migrations-Historie stehen

Getestet: Die Datei läuft auf einer frischen Postgres-16-Datenbank fehlerfrei durch und ergibt dieselben Objekte wie Dev (13 Tabellen, 40 Policies, 10 Funktionen in `private`, 2 Buckets, 15 Genres; Stand Migration 9, Migration 10 ergänzt nur einen Status-Wert).

Migration `20260731150000_fix_account_deletion.sql` ist bewusst nicht enthalten (von `20261016120000` überholt).

> `supabase/tests/rls_smoke.sql` **nie auf Prod** ausführen, nur auf Dev.

## 3. Edge Function (automatisierbar oder CLI)

`delete-account` deployen, **JWT-Verifikation an**:
`supabase functions deploy delete-account --project-ref <prod-ref>`

Prüfen: Aufruf ohne Token → `401`.

## 4. Auth (Dashboard → Authentication)

- **E-Mail-Bestätigung:** an. Templates auf Deutsch anpassen (Bestätigen, Passwort zurücksetzen)
- **Site URL:** `booksquad://auth-callback`
- **Redirect URLs:** `booksquad://auth-callback`
- **Leaked Password Protection:** an (Settings → Password Security)
- **Mindestlänge Passwort:** 8
- **SMTP:** eigener Absender (z. B. Resend, Postmark). Der eingebaute Supabase-Mailer ist auf wenige Mails pro Stunde begrenzt und für Prod ungeeignet
- **Rate Limits / CAPTCHA:** Standardwerte prüfen. Bei Spam-Registrierungen hCaptcha oder Turnstile aktivieren
- **Google Provider:** Web Client ID + Secret (siehe `docs/GOOGLE_APPLE_AUTH.md`)
- **Apple Provider:** Service ID, Team ID, Key ID, Private Key

## 5. Admin setzen (automatisierbar, nachdem du dich in der Prod-App registriert hast)

```sql
insert into private.admins (user_id)
select id from auth.users where email = '<deine-mail>';
```

## 6. Abschluss-Checks (automatisierbar)

- `get_advisors` (Security + Performance): Es bleiben nur die bekannten, gewollten Hinweise (öffentliche RPCs `username_available`, `join_group_with_code`, `am_i_admin` und die Admin-RPCs mit interner Prüfung)
- `.env` auf Prod umstellen, dann `tool/check_queries.sh`: Alle Abfragen müssen `ok` liefern
- Storage: Buckets `avatars` und `post-images` (5 MB, jpeg/png/webp)

## 7. Betrieb

- Backups: täglich (Pro). Point-in-Time Recovery bei Bedarf als Add-on
- Service-Role-Key **nie** in die App oder ins Repo
- Meldungen: Moderations-Queue in der App (Einstellungen → Meldungen prüfen). Benachrichtigung per Webhook ist ein offener Punkt (siehe `supabase/APPLY_MIGRATIONS.md`)
