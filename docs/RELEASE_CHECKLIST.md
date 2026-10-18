# Release-Anleitung für Marcello

Hier steht nur, was Claude **nicht** selbst erledigen kann: Konten, Passwörter, Geld, rechtliche Verantwortung und das Tippen in der App mit deinen Test-Konten. Alles andere übernimmt Claude. Wo **„→ Claude“** steht, gib kurz Bescheid, dann macht Claude weiter.

Die Reihenfolge ist absichtlich so gewählt:
- **Teil 1 ist kostenlos** und läuft komplett auf dem Dev-Projekt. Dein Supabase-Konto hat schon zwei Gratis-Projekte, ein drittes für Prod geht nur mit dem kostenpflichtigen Plan.
- **Teil 2 kostet Geld** und kommt ganz am Schluss.

---

## Teil 1 – Jetzt, kostenlos

### Schritt 1: Marke prüfen, Domains und Postfach kaufen (30 Min., ca. 2–5 €/Monat)

Der App-Name ist **Booksquad**. In App, Rechtstexten und Store-Texten stehen schon `getbooksquad.com` als Webseite und `support@getbooksquad.com` als Kontakt.

1. [ ] **Marke prüfen:** Bei [TMview](https://www.tmdn.org/tmview/) (EU und weltweit) und [USPTO](https://tmsearch.uspto.gov/) (USA) nach „Booksquad“ suchen. Gibt es eine eingetragene Marke für Apps, Software oder soziale Netzwerke (Klassen 9, 38, 42, 45) → Claude, bevor du etwas kaufst
2. [ ] **Domains kaufen:** `getbooksquad.com` und `booksquad.de`, am besten zusammen mit einem **E-Mail-Postfach** bei einem deutschen Anbieter (z. B. all-inkl, netcup, IONOS, Strato)
3. [ ] Postfach `support@getbooksquad.com` anlegen
4. [ ] → Claude: „Domains und Postfach sind da“, dazu den Anbieter nennen. Claude sagt dir, welche DNS-Einträge du für die Webseite (GitHub Pages) und die Weiterleitung von `booksquad.de` setzen musst
5. [ ] **Supabase Dev-Projekt → Authentication → URL Configuration:** Die Redirect-URL heißt jetzt `booksquad://auth-callback` (statt `bookmates://…`). Ohne diese Änderung öffnen Bestätigungs- und Passwort-Links die App nicht

### Schritt 2: Rechtstexte prüfen lassen

Name und Anschrift sind eingetragen, die E-Mail-Adresse auch.

- [ ] Die Texte in `docs/legal/` (Datenschutz, Nutzungsbedingungen, Impressum, Konto löschen) rechtlich prüfen lassen, z. B. durch einen Anwalt. Das geht parallel zu allen weiteren Schritten, muss aber vor Teil 2 fertig sein. Fragen für den Prüfer:
  - Reicht eine E-Mail-Adresse ohne Telefonnummer im Impressum?
  - Ist die Übermittlung an Open Library (USA) so korrekt beschrieben?
- [ ] → Claude: „Texte sind freigegeben“. Claude veröffentlicht die Seiten unter `getbooksquad.com`

### Schritt 3: E-Mail-Versand im Dev-Projekt einrichten (15 Min.)

Ohne diesen Schritt kommen Bestätigungs- und Passwort-Mails nicht an. Der eingebaute Supabase-Mailer schickt nur an Adressen aus deinem Supabase-Team und nur wenige Mails pro Stunde.

1. [ ] Beim Domain-Anbieter ein zweites Postfach `noreply@getbooksquad.com` anlegen und die **SMTP-Zugangsdaten** nachsehen (Server, Port, Benutzer, Passwort)
2. [ ] → Claude: Den Namen des Anbieters nennen. Claude trägt ihn als Maildienst in die Datenschutzerklärung ein (das Passwort behältst du)
3. [ ] Supabase Dashboard → Dev-Projekt → **Authentication → Emails → SMTP Settings** → „Enable custom SMTP“:
   - Host, Port, Benutzer und Passwort vom Anbieter
   - Sender email: `noreply@getbooksquad.com`, Sender name: `Booksquad`
4. [ ] **Authentication → Sign In / Providers → Email:** „Confirm email“ ist **an**
5. [ ] **Authentication → URL Configuration:**
   - Site URL: `booksquad://auth-callback`
   - Redirect URLs: `booksquad://auth-callback` (falls nicht schon eingetragen)

### Schritt 4: Google-Login einrichten (30 Min.)

1. [ ] [console.cloud.google.com](https://console.cloud.google.com) → neues Projekt „Booksquad“
2. [ ] **APIs & Dienste → OAuth-Zustimmungsbildschirm** (heißt teils „Google Auth Platform → Branding“):
   - App-Name „Booksquad“, Support-E-Mail aus Schritt 1
   - Zielgruppe „Extern“
   - Links auf Datenschutz und Nutzungsbedingungen, sobald die Seiten aus Schritt 2 online sind
3. [ ] **Clients → Client erstellen**, dreimal:
   - **Webanwendung**, Name „Supabase“. Autorisierte Weiterleitungs-URI: `https://thkfqvvzldkfxaqehjqn.supabase.co/auth/v1/callback`
   - **iOS**, Bundle-ID `com.booksquad.app`
   - **Android**, Paketname `com.booksquad.app`, SHA-1 `99:0F:08:74:EC:06:37:2E:16:87:DE:79:18:07:9B:16:2F:03:03:20` (das ist der Debug-Schlüssel dieses Macs)
4. [ ] Supabase → Dev-Projekt → **Authentication → Sign In / Providers → Google** → aktivieren:
   - Client ID und Client Secret vom **Web**-Client eintragen
   - Speichern
5. [ ] → Claude: **Web-Client-ID** und **iOS-Client-ID** schicken (beide enden auf `.apps.googleusercontent.com`; das sind keine Geheimnisse). Das Client Secret bleibt bei dir. Claude trägt die IDs in `.env` und `Info.plist` ein

### Schritt 5: Test-Konten anlegen (15 Min.)

Du brauchst vier E-Mail-Adressen. Mit Gmail geht das über Aliasse, alle Mails landen im selben Postfach: `deinname+a@gmail.com`, `+b`, `+c`, `+extra`.

1. [ ] → Claude: „App starten“. Claude startet die App im iPhone-Simulator
2. [ ] Mit deiner Haupt-Adresse registrieren. Der Bestätigungslink muss **im Simulator** geöffnet werden, nicht im Mac-Browser. Deshalb in der Mail am Mac: Rechtsklick auf den Link → „Link kopieren“ → → Claude schicken. Claude öffnet ihn im Simulator, die App meldet dich an. Auf einem echten Handy tippst du den Link einfach in der Mail-App an
3. [ ] → Claude: „Bin registriert, mach mich zum Admin“
4. [ ] Konten **A**, **B** und **C** genauso registrieren (für Social- und Moderations-Tests)

### Schritt 6: Testen (2–3 Std., gern auf mehrere Tage verteilt)

Die Tabellen mit Schritten und erwartetem Ergebnis stehen in `TESTING.md`. Du gehst sie in dieser Reihenfolge durch und hakst ab:

| # | Teil in `TESTING.md` | Worum es geht | Wo |
|---|---------------------|---------------|----|
| 1 | D (Auth) + Registrierung | Login, Logout, Passwort-Reset-Mail **inkl. Link öffnen**, Google-Login | iOS-Simulator |
| 2 | E (Profil & Regal) | Avatar, Bücher, Sterne, Statistik | iOS-Simulator |
| 3 | F (Feed & Beiträge) | Posten mit Buch und Bild, Liken, Kommentieren, Melden, Blockieren | iOS-Simulator |
| 4 | G (Social) | Folgen, Feed von anderen, Blockieren (Konten A und B) | iOS-Simulator |
| 5 | H (Lesekreise) | Öffentlich, privat, Beitritt per Code | iOS-Simulator |
| 6 | M (Moderation) | Melden mit A, B, C, Admin-Queue, Rate-Limit | iOS-Simulator |
| 7 | F2 (Feed & Bücher) | Endlos-Scroll, Like offline, Buch-Detailseite, Onboarding | iOS-Simulator |
| 8 | J (UI) | Große Schrift, VoiceOver, Flugmodus, Tastatur | iOS-Simulator |
| 9 | D, F, G, J noch einmal kurz | Android-Verhalten (Zurück-Taste, Google-Login, Tastatur) | Android, siehe unten |
| 10 | I (Konto löschen) | **Nur mit dem Konto `+extra`, ganz am Ende** | beliebig |

**Android:**
- Mit echtem Android-Handy: Einstellungen → Telefoninfo → 7× auf „Build-Nummer“ tippen → Entwickleroptionen → USB-Debugging an → per Kabel an den Mac → → Claude: „Handy ist dran“. Claude installiert die App
- Ohne Handy: → Claude: „Android-Emulator starten“. Ein Emulator ist auf dem Mac schon eingerichtet

**Wenn etwas nicht stimmt:** Test-ID (z. B. „F4“), was du gemacht hast, was passiert ist, am besten mit Screenshot → Claude. Claude behebt es, du testest die Stelle danach noch einmal.

### Schritt 7: Demo-Konto und Screenshots (30 Min.)

1. [ ] Ein Demo-Konto registrieren (z. B. `+demo`), Profilname wie eine echte Leserin oder ein echter Leser, kein echter Name
2. [ ] → Claude: „Demo-Konto ist da“. Claude füllt Regal, Beiträge und Lesekreise mit Beispieldaten im Dev-Projekt
3. [ ] Im iPhone-Simulator mit dem Demo-Konto eingeloggt lassen → → Claude: „Screenshots machen“. Claude nimmt die Screens auf und baut die Store-Bilder mit Bildtexten
4. [ ] Bilder ansehen und freigeben

**Ende von Teil 1:** Die App ist durchgetestet, die Rechtstexte sind geprüft und online, die Screenshots liegen bereit.

---

## Teil 2 – Am Schluss, kostet Geld

> **Zeitplan beachten, wenn die App dieses Jahr erscheinen soll:**
> - **Google** verlangt von neuen privaten Konten vor dem Produktivstart einen **geschlossenen Test mit mindestens 12 Personen über 14 Tage**. Danach folgt die Prüfung (einige Tage). Das Play-Konto sollte deshalb **spätestens Anfang Dezember** stehen, und die 12 Tester solltest du schon in Teil 1 suchen (Freunde, Familie, Lesekreis).
> - **Apple:** Die Kontoprüfung dauert 1–2 Tage (als Firma mit D-U-N-S-Nummer länger), das App-Review meist 1–3 Tage. Über die Feiertage arbeitet Apple langsamer.

### Schritt 8: Supabase Pro und Prod-Projekt (ca. 25 $/Monat)

1. [ ] Supabase → Organization → Billing → Plan **Pro**
2. [ ] Organization → Legal Documents → **AVV/DPA** abschließen (Pflicht nach DSGVO)
3. [ ] → Claude: „Prod-Projekt anlegen“. Claude legt es in Frankfurt an (nach deinem OK zu den Kosten), spielt Schema und Edge Function ein und trägt die Prod-Werte in `.env` ein
4. [ ] Im **Prod**-Projekt Schritt 3 (SMTP, Confirm email, URL Configuration) wiederholen
5. [ ] Authentication → Sign In / Providers → **Leaked password protection** an (nur im Pro-Plan verfügbar). Am besten im Dev-Projekt auch
6. [ ] Google Cloud: beim **Web**-Client zusätzlich die Weiterleitungs-URI des Prod-Projekts eintragen (`https://<prod-ref>.supabase.co/auth/v1/callback`; Claude nennt dir die Ref). Dann im Prod-Projekt den Google-Provider mit demselben Web-Client aktivieren
7. [ ] In der App (mit Prod-Build, → Claude) registrieren → → Claude: „Mach mich in Prod zum Admin“
8. [ ] Demo-Konto für das Apple-Review in Prod registrieren → → Claude füllt es mit Beispieldaten

### Schritt 9: Apple (99 €/Jahr)

1. [ ] [developer.apple.com/programs](https://developer.apple.com/programs/) → beitreten. Als Privatperson geht es am schnellsten
2. [ ] Xcode → Einstellungen → Accounts → mit dem Apple-Konto anmelden → → Claude: „Apple-Konto ist in Xcode“. Claude stellt Signing und Team ein
3. [ ] **Sign in with Apple** einrichten (developer.apple.com → Certificates, Identifiers & Profiles):
   - Unter Identifiers eine **Services ID** anlegen (z. B. `com.booksquad.app.signin`). Domain: `<prod-ref>.supabase.co`, Return URL: `https://<prod-ref>.supabase.co/auth/v1/callback`
   - Unter Keys einen **Key** mit „Sign in with Apple“ anlegen und die `.p8`-Datei herunterladen (gibt es nur einmal, sicher aufbewahren)
   - Supabase Prod → Providers → **Apple**: Services ID, Team ID, Key ID und Inhalt der `.p8` eintragen
4. [ ] [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Apps → **+ Neue App**:
   - Name „Booksquad – Lesen mit Freunden“ (ist er vergeben → Claude, für eine Alternative), Sprache Deutsch
   - Bundle-ID `com.booksquad.app`, SKU `booksquad`
5. [ ] Texte aus `docs/STORE_LISTING.md` einfügen, Screenshots aus Schritt 7 hochladen
6. [ ] **App-Datenschutz**, **Altersfreigabe** und Prüfnotizen nach `docs/STORE_PRIVACY.md` ausfüllen. Demo-Konto-Zugangsdaten **nur hier** eintragen
7. [ ] → Claude: „iOS-Build bauen“. Danach die `.ipa` mit der kostenlosen Mac-App **Transporter** (App Store) hochladen, Anmeldung mit deinem Apple-Konto
8. [ ] App Store Connect → **TestFlight**: Dich selbst als internen Tester eintragen, auf dem iPhone die App **TestFlight** installieren und Booksquad darüber laden
9. [ ] Auf dem **echten iPhone** testen: Apple-Login, Google-Login, Registrierung mit Bestätigungslink, Passwort-Reset-Link, Foto-Upload, Teil J aus `TESTING.md`. Fehler → Claude
10. [ ] Build der Version zuordnen → **Zur Prüfung einreichen**

### Schritt 10: Google Play (einmalig 25 $)

1. [ ] [play.google.com/console](https://play.google.com/console) → Konto als Privatperson anlegen, Identität bestätigen (dauert einige Tage)
2. [ ] **Upload-Schlüssel erzeugen:** → Claude gibt dir den fertigen `keytool`-Befehl. Du führst ihn im Terminal aus und vergibst die Passwörter selbst. Danach legst du `android/key.properties` nach der Vorlage in `docs/RELEASE.md` an. Keystore-Datei und Passwörter im Passwort-Manager sichern
3. [ ] Play Console → **App erstellen** (Name, Deutsch, App, kostenlos)
4. [ ] Store-Eintrag aus `docs/STORE_LISTING.md`, Screenshots, Feature-Grafik (→ Claude erstellt sie)
5. [ ] **App-Inhalte** ausfüllen: Datenschutz-URL, Datensicherheit, Einstufungsfragebogen, Zielgruppe ab 16, keine Werbung (alles in `docs/STORE_PRIVACY.md`)
6. [ ] → Claude: „Android-Build bauen“. Dann **Testen → Interner Test → Release erstellen** → `.aab` hochladen, Play App Signing akzeptieren
7. [ ] Play Console → Einrichtung → **App-Signatur**: Beide SHA-1-Werte (App-Signaturschlüssel und Upload-Schlüssel) kopieren und in Google Cloud je als weiteren **Android**-Client anlegen. Sonst funktioniert der Google-Login in der Play-Version nicht
8. [ ] **Geschlossener Test:** Release übernehmen, die 12 Tester per E-Mail-Liste einladen, Opt-in-Link verschicken. Die Tester müssen die App **14 Tage** installiert behalten
9. [ ] Danach **Zugriff auf Produktion beantragen**, die Fragen zum Test beantworten, Release in Produktion übernehmen

### Schritt 11: Nach der Freigabe

- [ ] → Claude: „Ist live“. Claude taggt die Version und bereitet das nächste Update vor
- [ ] Meldungen in der App regelmäßig prüfen (Einstellungen → Meldungen prüfen)
