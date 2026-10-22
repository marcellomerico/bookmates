# Booksquad — Testanleitung

Schritt-für-Schritt: Backend vorbereiten, App testen, Feedback geben.

**Dauer:** ca. 45–90 Minuten (mit 2 Test-Accounts)

---

## Voraussetzungen

- [ ] Supabase-Projekt auf [supabase.com](https://supabase.com)
- [ ] `.env` im Projektroot: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- [ ] App läuft: `flutter run`
- [ ] **2 verschiedene E-Mail-Adressen** (z. B. Gmail-Alias `+a` / `+b`)
- [ ] iPhone-Simulator oder echtes Gerät

---

# TEIL A — Backend vorbereiten

1. **Datenbank:** neues Projekt → `supabase/prod_setup.sql` einmal im SQL Editor ausführen. Bestehendes Projekt → fehlende Migrationen laut [`supabase/APPLY_MIGRATIONS.md`](supabase/APPLY_MIGRATIONS.md) einspielen.
2. **Edge Function** `delete-account` deployen (JWT-Verifikation an). Ohne sie schlägt „Account löschen“ fehl.
3. **Authentication → URL Configuration:** Redirect URL `booksquad://auth-callback` (Passwort-Reset, E-Mail-Bestätigung).
4. **Prüfen (nur DEV):** `supabase/tests/rls_smoke.sql` im SQL Editor → „ALL RLS CHECKS PASSED“, alles wird zurückgerollt. `tool/check_queries.sh` prüft die App-Abfragen gegen das Projekt.

---

# TEIL C — App vorbereiten

## C.1 Umgebung

```bash
cd ~/Developer/booksquad
flutter pub get
flutter run
```

- [ ] Kein „Booksquad Setup“-Screen → `.env` OK
- [ ] Login-Screen sichtbar

## C.2 Hot Restart

Nach Migrationen im Terminal **`R`** (Großbuchstabe), nicht nur `r`.

## C.0 Aufräumen (falls du schon getestet hast)

Wenn du vorher einen Account gelöscht hast und dieselbe E-Mail wieder nutzen willst — **zuerst prüfen**:

```sql
-- Ersetze durch deine Test-E-Mail
select id, email, created_at
from auth.users
where email = 'deine-email@example.com';
```

| Ergebnis | Aktion |
|----------|--------|
| **0 Zeilen** | ✅ E-Mail ist frei → weiter mit C.3 |
| **1 Zeile** | ❌ Account existiert noch → siehe Recovery unten |

**Recovery — hängengebliebener Account:**

1. Supabase → **Authentication** → **Users**
2. User mit der E-Mail suchen → **⋯** → **Delete user**
3. Nochmal SQL oben ausführen → 0 Zeilen
4. Optional: verwaistes Profil prüfen

```sql
select id, username, onboarding_completed
from public.profiles
where username = 'dein_gewünschter_username';
```

Profil ohne Auth-User? In Authentication den zugehörigen User löschen oder Username in der App wählen.

## C.3 Zwei Test-Accounts anlegen

**Regel:** User A und User B brauchen **zwei verschiedene E-Mail-Adressen**. Dieselbe E-Mail nie für beide Accounts — auch nicht nach Account-Löschung ohne Verifikation (C.0).

| Account | E-Mail | Passwort | Username |
|---------|--------|----------|----------|
| **User A** | z. B. `booksquad+a@test.com` | min. 8 Zeichen | z. B. `leser_a` |
| **User B** | z. B. `booksquad+b@test.com` | min. 8 Zeichen | z. B. `leser_b` |

### Schritt-für-Schritt User A

1. **Registrieren** mit E-Mail A, Passwort, Username A
2. **Erwartung:** Onboarding-Screen (Name, Genres, optional Buch)
3. Onboarding abschließen → **Home** (Feed)
4. **Abmelden** (Profil → Abmelden)

### Schritt-für-Schritt User B

5. **Registrieren** mit **E-Mail B** (nicht A!), Passwort, Username B
6. **Erwartung:** wieder **Onboarding** (nicht direkt Home!)
7. Onboarding abschließen → Home
8. Beide Zugangsdaten notieren

### Verifikation in der DB (nach C.3)

```sql
select u.email, p.username, p.onboarding_completed
from auth.users u
join public.profiles p on p.id = u.id
order by u.created_at desc
limit 5;
```

**Erwartung:** 2 Zeilen, unterschiedliche E-Mails, beide `onboarding_completed = true`

---

# TEIL D — Auth

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| D1 | User A: Anmelden | Home, kein Onboarding | |
| D2 | Abmelden → User B anmelden | Home, Profil von B | |
| D3 | Passwort vergessen → Link senden | Hinweis „Link geschickt“ | |
| D4 | Login: Auge-Icon am Passwort | Sichtbar/versteckt | |
| D5 | Registrieren: Auge-Icon | Toggle funktioniert | |

---

# TEIL E — Profil & Bücherregal

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| E1 | Profil bearbeiten → Avatar → Speichern | Avatar sichtbar | |
| E2 | Name, Bio, Genres ändern | Bleibt nach Tab-Wechsel | |
| E3 | Bücherregal → Hinzufügen → Buch suchen | Buch im Regal | |
| E4 | Status am Buch ändern | Tab wechselt korrekt | |
| E5 | Tab Gelesen → Sterne | Bewertung gespeichert | |
| E6 | Buch entfernen | Weg aus Regal | |
| E7 | Meine Beiträge | Liste (leer oder Posts) | |
| E8 | Stats Beiträge/Follower/Folgt | Echte Zahlen | |
| E9 | Follower / Folgt tippen | Listen öffnen | |
| E10 | Support kontaktieren | Mail-App öffnet | |
| E11 | Datenschutz / AGB / Impressum | Link öffnet die Seite auf booksquad.de | |

---

# TEIL F — Feed & Beiträge

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| F1 | Tab Post → Text → Teilen | Post im Feed | |
| F2 | Post mit Buch aus Regal | Buch-Chip am Post | |
| F3 | Post mit Bild | Bild sichtbar | |
| F4 | Herz tippen | Gefüllt, +1 | |
| F5 | Herz nochmal | Unlike, −1 | |
| F6 | Post öffnen → Kommentar | In Liste | |
| F7 | Eigener Post → Löschen | Verschwindet | |
| F8 | User B's Post → Melden | Bestätigung | |
| F9 | User B's Post → Blockieren | Blockiert | |
| F10 | Feed-Suche | Wechsel zu Entdecken | |
| F11 | Glocke | Aktivität-Screen | |
| F12 | App killen → neu starten | Daten noch da | |

---

# TEIL G — Social (2 Accounts)

User A und B abwechselnd (Abmelden/Anmelden).

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| G1 | User A → Entdecken → User B suchen | Gefunden | |
| G2 | Folgen | → Entfolgen | |
| G3 | User B → Post erstellen | Im Feed | |
| G4 | User A → Feed | Post von B sichtbar | |
| G5 | Profil von B | Beiträge + Regal read-only | |
| G6 | Leser für dich → Folgen | Funktioniert | |
| G7 | User A Stats | Follower/Folgt aktualisiert | |
| G8 | Blockierter User | Nicht mehr im Feed | |

---

# TEIL H — Gruppen

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| H1 | Club → Neu → öffentlich | In Liste | |
| H2 | Neu → Private Gruppe | Schloss-Icon | |
| H3 | User B sieht private Gruppe nicht | Nicht in Liste | |
| H4 | User B tritt per Invite-Code bei (siehe H8–H10) | Mitglied | |
| H5 | Mitglied → Beitrag in Gruppe | Post sichtbar | |
| H6 | Nicht-Mitglied | Kein FAB Beitrag | |
| H7 | Creator löscht Gruppe | Weg | |

## Private Gruppe per Invite-Code beitreten

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| H8 | User A (Creator): private Gruppe öffnen | Invite-Code sichtbar | |
| H9 | User B: Gruppen → **Code**-Button → falschen Code eingeben | Fehlermeldung, kein Beitritt | |
| H10 | User B: Code von A eingeben | Beitritt, Gruppe in Liste | |

---

# TEIL I — Account löschen

**Nur mit einem Extra-Test-Account** (nicht User A/B, die du für G brauchst), oder am Ende wenn Social-Tests fertig sind.

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| I1 | Extra-Account registrieren + Onboarding | Home | |
| I2 | Profil → Einstellungen → Konto löschen → bestätigen | Snackbar „gelöscht“, Login-Screen | |
| I3 | Mit gelöschtem Account anmelden | Fehler, kein Login | |
| I4 | SQL: E-Mail in auth.users | **0 Zeilen** (siehe unten) | |

**Verifikation nach I2** (E-Mail des gelöschten Accounts einsetzen):

```sql
select id, email from auth.users where email = 'extra-test@example.com';
-- Erwartung: 0 Zeilen

select id, username from public.profiles where username = 'extra_test_user';
-- Erwartung: 0 Zeilen
```

| I4 Ergebnis | Bedeutung |
|-------------|-----------|
| 0 Zeilen in beiden | ✅ Löschung vollständig |
| User noch in auth.users | ❌ Edge Function `delete-account` nicht deployed oder Löschung fehlgeschlagen — Fehlermeldung in App prüfen |

> **Erst nach I4 = ✅** dieselbe E-Mail wieder für einen neuen Account nutzen.

---

# TEIL M — Moderation, Spam-Schutz, Nutzungsbedingungen

**Voraussetzung:** Migration 7 ist angewendet, und dein Account ist Admin (`private.admins`, siehe `supabase/APPLY_MIGRATIONS.md`). Für M2 brauchst du drei Test-Accounts (A, B, C) plus deinen Admin-Account.

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| M1 | Registrieren ohne Haken bei Nutzungsbedingungen | Fehlermeldung, kein Konto angelegt | |
| M2 | A postet etwas. B, C und der Admin melden den Post über „…“ → „Melden“ | Nach der 3. Meldung sehen B, C und andere den Post nicht mehr. A sieht ihn mit dem Hinweis „Ausgeblendet nach Meldungen“. | |
| M3 | B meldet denselben Post nochmal | „Du hast das bereits gemeldet.“ | |
| M4 | Admin: Profil → Einstellungen → „Meldungen prüfen“ | Meldungen erscheinen mit Grund, Melder, Inhaltsauszug und Badge „ausgeblendet“ | |
| M5 | Admin: „Verwerfen“ | Post ist für alle wieder sichtbar, die Meldungen verschwinden aus der Liste | |
| M6 | Erneut melden lassen, Admin: „Löschen“ und bestätigen | Post ist für alle weg, auch für A | |
| M7 | Kommentar dreimal melden (verschiedene Accounts) | Nur der Kommentar wird ausgeblendet, der Post bleibt sichtbar | |
| M8 | Profil melden, Admin: „Erledigt“ | Meldung verschwindet; „Ausblenden“ und „Löschen“ werden hier nicht angeboten | |
| M9 | Nicht-Admin-Account: Einstellungen öffnen | Kein Button „Meldungen prüfen“ | |
| M10 | 11 Beiträge innerhalb von 10 Minuten posten | Ab dem 11.: „Zu viele Aktionen in kurzer Zeit…“ | |

---

# TEIL J — UI & Stabilität

**UI-Checks** (am besten auf einem echten iPhone und einem Android-Gerät):

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| U1 | iOS: Beitrag öffnen, vom linken Rand nach rechts wischen | Zurück zum Feed (Back-Swipe) | |
| U2 | Kommentar schreiben | Eingabefeld bleibt über der Tastatur sichtbar | |
| U3 | Systemschrift auf größte Stufe (iOS: Bedienungshilfen → Größerer Text) | Nichts abgeschnitten, Regal und Profil scrollen normal | |
| U4 | VoiceOver/TalkBack: Feed durchwischen | Like-, Kommentar- und Optionen-Buttons werden vorgelesen | |
| U5 | Login mit Passwort-Manager | E-Mail und Passwort werden vorgeschlagen und eingefüllt | |
| U6 | In einem Lesekreis „Beitrag“ → posten | Chip „Wird gepostet in: …“, danach zurück im Lesekreis, Formular leer | |
| U7 | Profil → Zahnrad | Einstellungen mit Rechtlichem, Lizenzen, Abmelden, Konto löschen | |
| U8 | Flugmodus an, Feed aktualisieren | Fehlerzustand mit „Erneut versuchen“ statt leerer Seite | |

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| J1 | Notch / Dynamic Island | Nicht verdeckt | |
| J2 | Tastatur bei Textfeldern | Kein Overflow | |
| J3 | Bottom Nav wechseln | Animation, kein Crash | |
| J4 | Pull-to-Refresh | Feed, Profil, … | |
| J5 | Navbar unten | Durchgängig, kein Streifen | |

---

# TEIL F2 — Feed & Bücher

| ID | Schritte | Erwartung | ✅ / ❌ |
|----|----------|-----------|--------|
| F2-1 | Feed mit > 20 Beiträgen nach unten scrollen | Weitere Beiträge laden automatisch nach, unten erscheint kurz ein Ladekreis | |
| F2-2 | Beitrag liken | Herz und Zahl ändern sich sofort, ohne dass der Feed neu lädt | |
| F2-3 | Flugmodus an, liken | Like springt zurück, Fehlermeldung erscheint | |
| F2-4 | Buch im Beitrag, im Regal oder in der Suche antippen | Buch-Detailseite mit Beschreibung, Themen und Leserzahl | |
| F2-5 | Auf der Buch-Detailseite den Status wählen | Buch landet im Regal; Status wechseln oder entfernen funktioniert | |
| F2-6 | Neuer Account: Onboarding bis zu „Leser, die deinen Geschmack teilen“ | Vorschläge oder freundlicher Leerzustand; Folgen und Beitreten reagieren sofort | |

# TEIL K — Automatisierte Tests

**Abfragen gegen das Backend prüfen:** `tool/check_queries.sh` testet alle Datenbank-Abfragen der App mit dem Anon-Key gegen das in `.env` eingetragene Projekt (z. B. nach Migrationen). Alles muss `ok` sein.


```bash
flutter analyze    # Erwartung: No issues found
flutter test       # Erwartung: All tests passed
```

---

# Troubleshooting

## „Registrierung fehlgeschlagen, E-Mail bereits registriert“

1. Alle Migrationen eingespielt und Edge Function deployed? (Teil A)
2. SQL aus C.0 — existiert die E-Mail noch in `auth.users`?
3. Ja → User in **Authentication → Users** manuell löschen
4. App: **`R`** Hot Restart, erneut registrieren

## „Anmeldung geht, aber kein Onboarding (alter Account)“

Du bist im **bestehenden** Auth-User, nicht in einem neuen.

- Profil prüfen: alter Username / alte Daten?
- `onboarding_completed` war schon `true` vom ersten Account
- **Kein App-Bug** — Auth-User wurde nicht gelöscht

**Fix:** Account in Supabase Dashboard löschen (C.0), dann neu registrieren mit **neuer** E-Mail oder nach verifizierter Löschung (I4).

## „Account löschen“ zeigt Erfolg, Login klappt trotzdem

- Edge Function `delete-account` nicht deployed → Löschung scheitert
- App zeigt eine **Fehlermeldung**, wenn die Function scheitert (nach Update + Hot Restart)
- SQL I4 ausführen

## „Dieser Benutzername ist bereits vergeben“

Username hängt am alten Profil:

```sql
select id, username from public.profiles where username = 'leser_a';
```

Anderen Username wählen **oder** zugehörigen Auth-User löschen.

## E-Mail-Bestätigung (Supabase)

Wenn unter **Authentication → Providers → Email** „Confirm email“ aktiv ist:

- Nach Registrierung erscheint Dialog „E-Mail bestätigen“
- Erst nach Klick im Postfach funktioniert Login
- Bis dahin wirkt es wie „Account existiert, Login geht nicht“

---

# Feedback-Vorlage

```
=== BACKEND ===
rls_smoke.sql: ✅ / ❌

=== APP ===
C.3 Zwei Accounts: ✅ / ❌
D Auth: ✅ / ❌
E Profil: ✅ / ❌
F Feed: ✅ / ❌
G Social: ✅ / ❌
H Gruppen: ✅ / ❌
I Account löschen: ✅ / ❌ / übersprungen
J UI: ✅ / ❌
K flutter test: ✅ / ❌

=== BUGS ===
1. Test-ID, Schritte, erwartet, passiert

=== GERÄT ===
Simulator / Gerät, iOS: …
```

---

# Bekannte Ausnahmen (kein Bug)

| Thema | Grund |
|-------|--------|
| Google/Apple Login | Dashboard-Config → `docs/GOOGLE_APPLE_AUTH.md` |
| Legal-URLs | `booksquad.de` |
| „Policy already exists“ | Migration teilweise gelaufen, `rls_smoke.sql` zeigt, ob alles stimmt |

---

# Dateien

| Datei | Zweck |
|-------|--------|
| `supabase/migrations/` | Alle Migrationen, Liste in `supabase/APPLY_MIGRATIONS.md` |
| `supabase/prod_setup.sql` | Alle Pflicht-Migrationen in einem Durchlauf (neues Projekt) |
| `supabase/functions/delete-account` | Edge Function |
| `supabase/tests/rls_smoke.sql` | RLS-Test (nur DEV) |

---

# Empfohlene Test-Reihenfolge

1. Teil A (Backend), dann App starten (C.1)
2. **C.3**: User A und User B mit **zwei verschiedenen E-Mails**
3. D → E → F → G → H → M → F2 → J, Konto löschen (I) zuletzt mit einem Wegwerf-Konto
