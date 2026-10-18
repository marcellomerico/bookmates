# Release-Plan Booksquad

Alles, was du selbst erledigen kannst, in der richtigen Reihenfolge. Dazu die Kosten, ein Zeitplan und was warten kann. Wo **„→ Claude“** steht, gib kurz Bescheid, dann übernimmt Claude den Rest.

Stand: 18. Oktober 2026. Preise geprüft bei Apple, Google und Supabase. Domain-Preise schwanken je nach Anbieter.

---

## 1. Auf einen Blick

| Phase | Was passiert | Kosten | Dauer |
|---|---|---|---|
| **0 · Jetzt** | Du klickst dich selbst durch die App | 0 € | 30 Min. |
| **A · Vorbereitung** | Marke, Domain, Rechtstexte, Datenbank-Einstellungen, Google-Login, Tester sammeln, Testen | ca. 5–60 € | 1–2 Wochen |
| **B · Beta** | TestFlight (iPhone) und geschlossener Test bei Google Play mit echten Testern | ca. 125 € | mind. 14 Tage (Google-Pflicht) |
| **C · Start** | Eigenes Produktions-Backend, Store-Einträge, Prüfung, Veröffentlichung | ca. 27 €/Monat | 1–2 Wochen |
| **D · Später** | Webseite, Marke anmelden, Englisch, Push, Premium | je nach Wunsch | – |

**Direkt veröffentlichen geht nicht, bei Google jedenfalls nicht:**
- **Apple:** Du *könntest* nach der App-Prüfung direkt veröffentlichen. Sinnvoll ist trotzdem erst TestFlight, damit echte Leute die App vorher benutzen.
- **Google:** Neue private Entwicklerkonten **müssen** vorher einen geschlossenen Test machen. Bedingung: mindestens **12 Tester**, **14 Tage am Stück** angemeldet. Erst danach kannst du die Veröffentlichung beantragen. Fällt die Zahl unter 12, beginnen die 14 Tage laut Erfahrungsberichten von vorn. Plane deshalb 15–20 Tester ein. Ausgenommen sind nur Firmenkonten, und die brauchen eine D-U-N-S-Nummer.

### Zeitplan, wenn die App noch dieses Jahr erscheinen soll

| Zeitraum | Ziel |
|---|---|
| bis ca. 31. Oktober | Phase A: Domain, Rechtstexte zur Prüfung, Datenbank eingerichtet, Tester gefunden |
| bis ca. 15. November | Apple- und Google-Konto stehen (Identitätsprüfung dauert ein paar Tage) |
| ab ca. 15. November | Beta läuft: TestFlight und geschlossener Test bei Google |
| ca. 29. November | 14 Tage Google-Test erfüllt → Veröffentlichung beantragen |
| Anfang bis Mitte Dezember | Öffentlicher Start (Apple und Google prüfen meist in 1–3 Tagen, über Weihnachten langsamer) |

Bei Google ist der späteste sinnvolle Start des Tests ungefähr der **20. November**. Später wird es vor Weihnachten knapp.

---

## 2. Kosten

### Pflicht

| Posten | Wann | Kosten | Hinweis |
|---|---|---|---|
| Domain `getbooksquad.com` | Phase A | ca. 10–15 €/Jahr | Auf den **Verlängerungspreis** achten, nicht nur aufs erste Jahr |
| Domain `booksquad.de` | Phase A | ca. 2–10 €/Jahr | Bei günstigen Anbietern dauerhaft unter 5 € |
| E-Mail-Postfach (`support@`, `noreply@`) | Phase A | ca. 0–5 €/Monat | Oft im Domain-Paket enthalten. Ohne eigenes Postfach bekommen deine Tester keine Bestätigungsmails |
| Apple Developer Program | Phase B | **99 €/Jahr** | Verlängert sich automatisch. Nur nötig, solange die App im App Store sein soll |
| Google Play Console | Phase B | **25 $ einmalig** (ca. 23 €) | Keine jährliche Gebühr |
| Supabase Pro (Produktion) | Phase C | **25 $/Monat** (ca. 23 € + ggf. 19 % USt, also ca. 27 €) | Ein Projekt inklusive. Die Rechenleistung für ein kleines Projekt ist durch ein 10-$-Guthaben abgedeckt |

### Empfohlen

| Posten | Kosten | Hinweis |
|---|---|---|
| Rechtliche Prüfung der Texte | ca. 150–600 € einmalig | Alternative: Rechtstext-Dienst im Abo, ca. 10–25 €/Monat. Die Texte werden dort gepflegt, sind aber allgemeiner |
| Mailversand über Resend o. ä. | 0 € (bis ca. 3.000 Mails/Monat) | Nur nötig, wenn dein Postfach-Anbieter kein SMTP erlaubt |

### Optional, später

| Posten | Kosten | Hinweis |
|---|---|---|
| Marke beim DPMA (Deutschland) | ca. 290 € für 10 Jahre (bis 3 Klassen) | Schützt den Namen in Deutschland |
| EU-Marke (EUIPO) | ca. 850 € (1 Klasse) | Schützt den Namen EU-weit |
| Android-Testhandy | ca. 100–200 € | Nur wenn du keins hast. Der Emulator reicht für viel |
| Gewerbeanmeldung | ca. 20–60 € | Erst wenn Geld fließt (Premium). Dann auch Steuern beachten |

### Was das unterm Strich heißt

| Zeitraum | Minimum | Realistisch (mit Anwalt) |
|---|---|---|
| Bis zur Beta | ca. 140 € | ca. 140 € |
| Erstes Jahr bis einschließlich Start | ca. 300 € | ca. 600–900 € |
| Jedes weitere Jahr (laufend) | ca. 450 € (Apple 99 € + Supabase ca. 325 € + Domains/Mail) | dito |

### Kostenfallen

- **Supabase rechnet pro Organisation, nicht pro Projekt.** In deiner jetzigen Organisation liegen *Intervelo* und das Booksquad-Dev-Projekt. Würdest du sie auf Pro umstellen, zahlst du für beide Projekte mit. **Lege für die Produktion eine neue Organisation „Booksquad“ an** und stelle nur diese auf Pro. Die alte bleibt kostenlos.
- **Die Beta läuft kostenlos auf dem Dev-Projekt.** Dein Konto hat schon zwei Gratis-Projekte, ein drittes geht nicht ohne Pro. Für die Beta reicht das Dev-Projekt. Zwei Einschränkungen: Gratis-Projekte pausieren nach **einer Woche ohne Nutzung**, und es gibt keine automatischen Backups. Sag den Testern, dass ihre Beta-Daten beim Start nicht übernommen werden.
- **Domain-Lockangebote:** „0 € im ersten Jahr“ heißt oft 15–20 €/Jahr danach, und Mail-Pakete werden nach dem ersten Jahr teurer. Vergleiche die Verlängerungspreise.
- **Domain über einen Bekannten (z. B. Jonas):** Gerne, aber die Domain muss **auf deinen Namen** registriert sein. Du bist dort Inhaber und hast den Zugang. Sonst hängt deine App an jemand anderem.
- **Apple verlängert automatisch.** Ohne Mitgliedschaft verschwindet die App aus dem Store.

---

## 3. Was ist Pflicht, was kann warten?

| | Vor der Beta | Vor dem Start | Kann warten |
|---|---|---|---|
| Marke prüfen | ✅ | | |
| Domain und Postfach | ✅ (Mails an Tester) | | |
| Rechtstexte online | ✅ (Stores verlangen den Link) | | |
| Rechtstexte anwaltlich geprüft | | ✅ | |
| Datenbank-Einstellungen (Mail, Links) | ✅ | | |
| Google-Login | ✅ | | |
| Apple-Login | ✅ für TestFlight | | |
| 15–20 Tester | ✅ | | |
| Eigenes Produktions-Backend (Pro) | | ✅ | |
| Webseite / Landingpage | | | ✅ (die Rechtstexte-Seite reicht zum Start) |
| Marke anmelden | | | ✅ |
| Englische Version | | | ✅ |
| Push-Benachrichtigungen | | | ✅ |
| Premium-Funktionen | | | ✅ |

---

## 4. Phase 0 · Jetzt: App selbst ansehen (0 €)

Zwei Wege, beide im iPhone-Simulator auf deinem Mac:

**a) Die echte App, mit echter Datenbank**
- [ ] → Claude: „Starte die App“
- [ ] Mit deinem **bestehenden Dev-Konto** anmelden (deine Gmail-Adresse, das Passwort kennst du). Das Konto ist bereits **Admin**, du siehst also auch „Meldungen prüfen“
- Feed, Entdecken und Lesekreise sind noch fast leer, weil du der einzige Nutzer bist. Lege ruhig Bücher, Beiträge und einen Lesekreis an

**b) Der Demo-Modus, mit Beispieldaten**
- [ ] → Claude: „Starte den Demo-Modus“. Die App ist dann voll mit Lesern, Beiträgen und Lesekreisen, so wie auf den Store-Bildern. Nichts davon landet in der Datenbank

**Feedback:** Notiere, was dir auffällt, am besten mit Screenshot (im Simulator ⌘S) → Claude. Design schlicht lassen, Fokus auf Kernfunktionen: Regal, Beitrag schreiben, Feed, Lesekreis.

---

## 5. Phase A · Vorbereitung

### A1 Marke prüfen (10 Min., 0 €)
- [ ] [TMview](https://www.tmdn.org/tmview/) (EU und weltweit) und [DPMA-Register](https://register.dpma.de) (Deutschland) nach „Booksquad“ durchsuchen. Relevant sind die Klassen 9 (Software), 38 (Telekommunikation), 41 (Bildung, Unterhaltung), 42 (IT-Dienste) und 45 (soziale Netzwerke)
- [ ] Optional: [USPTO](https://tmsearch.uspto.gov/) (USA), wegen des weltweiten Starts
- Treffer in diesen Klassen → Claude, bevor du etwas kaufst

### A2 Domains und Postfach (30 Min., ca. 5–60 €/Jahr)
- [ ] `getbooksquad.com` und `booksquad.de` kaufen, **auf deinen Namen**
- [ ] Postfächer anlegen: `support@getbooksquad.com` (Kontakt) und `noreply@getbooksquad.com` (App-Mails)
- [ ] Beim Anbieter die **SMTP-Daten** nachsehen: Server, Port, Benutzer, Passwort
- [ ] → Claude: „Domains sind da“, dazu den Anbieter nennen. Claude merged die Umbenennung (PR #9) und nennt dir die DNS-Einträge für:
  - die Webseite (`getbooksquad.com` → GitHub Pages)
  - die Weiterleitung von `booksquad.de`
  - die Mail-Absicherung (SPF, DKIM), damit App-Mails nicht im Spam landen
- [ ] DNS-Einträge beim Anbieter eintragen

### A3 Rechtstexte (Prüfung 1–2 Wochen, ca. 150–600 €)
Name, Anschrift und E-Mail stehen schon drin.
- [ ] → Claude: „Rechtstexte veröffentlichen“ (sobald die Domain steht). Die Seiten gehen unter `getbooksquad.com` online
- [ ] Texte prüfen lassen (Anwalt oder Rechtstext-Dienst). Fragen für den Prüfer:
  - Reicht eine E-Mail-Adresse ohne Telefonnummer im Impressum?
  - Ist die Übermittlung an Open Library (USA) richtig beschrieben?
  - Passen die Nutzungsbedingungen (inkl. Digital Services Act) zu einem kostenlosen Angebot?
- [ ] Änderungswünsche → Claude

### A4 Datenbank: alles, was du im Supabase-Dashboard selbst machst (45 Min., 0 €)
Gilt jetzt für das **Dev-Projekt** (das ist auch das Beta-Backend). Für die Produktion wiederholst du es in Phase C. Dashboard: [supabase.com/dashboard](https://supabase.com/dashboard) → Projekt „marcellomerico's Project“ (Ref `thkfqvvzldkfxaqehjqn`).

1. [ ] **Dein Supabase-Konto absichern:** Konto (oben rechts) → Account → **Multi-Factor Authentication** an. Wer dein Konto hat, hat alle Nutzerdaten
2. [ ] **Authentication → URL Configuration:**
   - Site URL: `booksquad://auth-callback`
   - Redirect URLs: `booksquad://auth-callback`. Ein alter Eintrag mit dem früheren Namen kann weg. Ohne diesen Eintrag öffnen Bestätigungs- und Passwort-Links die App nicht
3. [ ] **Authentication → Emails → SMTP Settings** → „Enable custom SMTP“ mit den Daten aus A2:
   - Sender: `noreply@getbooksquad.com`, Name `Booksquad`
   - Ohne eigenes SMTP schickt Supabase nur an Mitglieder deines Supabase-Teams. Deine Tester bekämen keine Mails
4. [ ] **Authentication → Emails → Templates:** deutsche Texte für „Confirm signup“ und „Reset password“ → Claude liefert die fertigen Vorlagen zum Einfügen
5. [ ] **Authentication → Sign In / Providers → Email:** „Confirm email“ **an**, minimale Passwortlänge **8**
6. [ ] **Authentication → Rate Limits:** Standardwerte ansehen. Mails pro Stunde ggf. auf 30 erhöhen, sobald eigenes SMTP läuft
7. [ ] **Advisors → Security Advisor:** Erwartet sind nur die bekannten Hinweise. Neue Warnungen → Claude
8. [ ] **Table Editor:** einfach mal reinschauen (Tabellen `profiles`, `posts`, `groups`, `reports`). Ändere hier nichts von Hand, dafür gibt es die App und die Moderation
9. [ ] Weitere Admins (z. B. eine Mitmoderatorin) später im **SQL Editor** eintragen:
   ```sql
   insert into private.admins (user_id)
   select id from auth.users where email = 'mail@beispiel.de';
   ```
10. [ ] Merken: Das Dev-Projekt pausiert nach einer Woche ohne Nutzung. Dann im Dashboard auf „Restore“ klicken (oder → Claude)

### A5 Google-Login (30 Min., 0 €)
1. [ ] [console.cloud.google.com](https://console.cloud.google.com) → neues Projekt „Booksquad“
2. [ ] **Google Auth Platform → Branding:**
   - App-Name „Booksquad“, Support-Mail `support@getbooksquad.com`
   - Links: `https://getbooksquad.com/privacy.html` und `https://getbooksquad.com/terms.html`
   - Autorisierte Domain: `getbooksquad.com`
3. [ ] **Zielgruppe:** „Extern“. Im Status „Testen“ können sich nur eingetragene Test-Nutzer (bis 100) anmelden, also die Beta-Tester eintragen. Vor dem Start auf **„In Produktion“** stellen. Für die einfachen Berechtigungen (E-Mail, Profil) braucht es keine Google-Prüfung
4. [ ] **Clients → Client erstellen**, dreimal:
   - **Webanwendung** „Supabase“, Weiterleitungs-URI: `https://thkfqvvzldkfxaqehjqn.supabase.co/auth/v1/callback`
   - **iOS**, Bundle-ID `com.booksquad.app`
   - **Android**, Paket `com.booksquad.app`, SHA-1 `99:0F:08:74:EC:06:37:2E:16:87:DE:79:18:07:9B:16:2F:03:03:20` (Debug-Schlüssel dieses Macs)
5. [ ] Supabase → **Authentication → Sign In / Providers → Google:** Client ID und Secret vom **Web**-Client eintragen
6. [ ] → Claude: Web- und iOS-Client-ID schicken (keine Geheimnisse). Das Secret behältst du

### A6 Tester sammeln (laufend, 0 €)
- [ ] **15–20 Leute** finden (Freunde, Familie, Lesekreis, Kolleginnen). Google verlangt 12, der Rest ist Puffer
- [ ] Liste führen mit Name, **Google-Konto-Mail** (für Play), **Apple-ID-Mail** (für TestFlight) und Gerät (iPhone/Android)
- [ ] Mit den Testern absprechen:
  - die App 14 Tage installiert lassen
  - sie ab und zu benutzen
  - Feedback geben

### A7 Selbst testen (2–3 Std., 0 €)
- [ ] Testreihenfolge aus `TESTING.md` im iPhone-Simulator durchgehen: D → E → F → G → H → M → F2 → J, Konto löschen (I) zuletzt mit einem Wegwerf-Konto
- [ ] Für Social-Tests zweite und dritte Adresse nutzen (Gmail-Alias: `deinname+b@gmail.com`)
- [ ] Android: Handy per USB anschließen (Entwickleroptionen → USB-Debugging) oder → Claude startet den Emulator
- [ ] Fehler mit Test-ID und Screenshot → Claude

---

## 6. Phase B · Beta (ca. 125 €, mind. 14 Tage)

### B1 Apple Developer Program (99 €/Jahr)
1. [ ] [developer.apple.com/programs](https://developer.apple.com/programs/) → als **Privatperson** registrieren (ein bis zwei Tage Prüfung). Als Firma bräuchtest du eine D-U-N-S-Nummer, das dauert länger
2. [ ] Xcode → Einstellungen → Accounts → mit dem Apple-Konto anmelden → → Claude: „Apple-Konto ist in Xcode“ (Claude stellt Team und Signing ein)
3. [ ] **Sign in with Apple** einrichten (developer.apple.com → Certificates, Identifiers & Profiles):
   - **Services ID** anlegen, z. B. `com.booksquad.app.signin`
     - Domain: `thkfqvvzldkfxaqehjqn.supabase.co`
     - Return URL: `https://thkfqvvzldkfxaqehjqn.supabase.co/auth/v1/callback`
   - **Key** mit „Sign in with Apple“ erzeugen, die `.p8`-Datei laden (gibt es nur einmal, sicher aufbewahren)
   - Supabase → Providers → **Apple**: Services ID, Team ID, Key ID und Inhalt der `.p8`
   - Pflicht: Apple verlangt Apple-Login, sobald eine App Google-Login anbietet
4. [ ] [App Store Connect](https://appstoreconnect.apple.com) → **Neue App**: Name „Booksquad – Lesen mit Freunden“, Deutsch, Bundle-ID `com.booksquad.app`, SKU `booksquad`

### B2 TestFlight
1. [ ] → Claude: „iOS-Beta bauen“. Claude baut die App gegen das Dev-Backend
2. [ ] Die `.ipa` mit der kostenlosen Mac-App **Transporter** hochladen. Anmeldung mit deiner Apple-ID
3. [ ] App Store Connect → TestFlight → **Interne Tester:** dich selbst eintragen (bis 100 Personen, die in deinem App-Store-Connect-Team sind, ohne Prüfung)
4. [ ] **Externe Tester:** Gruppe „Beta“ anlegen, Testinfos ausfüllen (was testen, Kontakt), zur **Beta-Prüfung** einreichen. Die erste Prüfung dauert meist 1–2 Tage. Danach Einladung per Mail oder öffentlichem Link (bis 10.000 Tester)
5. [ ] Tester installieren die App **TestFlight** aus dem App Store und dann Booksquad darüber
6. [ ] Builds laufen nach **90 Tagen** ab. Bei längeren Betas → Claude baut neu

### B3 Google Play (25 $ einmalig)
1. [ ] [play.google.com/console](https://play.google.com/console) → Konto als **Privatperson** anlegen, Identität bestätigen (ein paar Tage)
2. [ ] **Upload-Schlüssel:** → Claude gibt dir den `keytool`-Befehl. Du führst ihn aus und vergibst die Passwörter selbst. Danach `android/key.properties` nach Vorlage anlegen. Schlüssel und Passwörter im Passwort-Manager sichern
3. [ ] **App erstellen:** Name, Deutsch, App, kostenlos. Unter **App-Inhalte** ausfüllen: Datenschutz-URL, Datensicherheit, Einstufung, Zielgruppe ab 16, keine Werbung. Die Antworten stehen in `docs/STORE_PRIVACY.md`
4. [ ] → Claude: „Android-Beta bauen“ → unter **Testen → Interner Test** die `.aab` hochladen, „Play App Signing“ akzeptieren
5. [ ] **Einrichtung → App-Signatur:** beide SHA-1-Werte (App-Signatur und Upload) in der Google Cloud je als weiteren **Android-Client** anlegen. Sonst geht der Google-Login in der Play-Version nicht
6. [ ] **Testen → Geschlossener Test:** Release übernehmen, Tester-Liste mit den Google-Mails aus A6 anlegen, Opt-in-Link verschicken
7. [ ] **14 Tage abwarten** und darauf achten, dass mindestens 12 Tester angemeldet bleiben

### B4 Feedback-Runde
- [ ] Rückmeldungen sammeln (TestFlight hat eine eingebaute Feedback-Funktion, Google Play nicht: also Mail an `support@`)
- [ ] Wichtiges → Claude, neue Beta-Builds nach Bedarf

---

## 7. Phase C · Öffentlicher Start (ca. 27 €/Monat)

### C1 Produktions-Backend
1. [ ] Supabase → **neue Organisation „Booksquad“** → Plan **Pro** (nicht deine bestehende Organisation, siehe Kostenfallen)
2. [ ] In der neuen Organisation: Legal Documents → **AVV/DPA** abschließen (DSGVO-Pflicht)
3. [ ] → Claude: „Prod-Projekt anlegen“. Claude legt es in Frankfurt an, spielt Schema und Edge Function ein, prüft alles und stellt die App auf Prod um
4. [ ] A4 Schritte 2–6 im **Prod-Projekt** wiederholen, zusätzlich: **Leaked password protection** an (gibt es nur im Pro-Plan)
5. [ ] Google Cloud: beim Web-Client die Prod-Weiterleitungs-URI ergänzen, Google- und Apple-Provider im Prod-Projekt eintragen (dieselben Werte wie in Dev, nur die Supabase-Adresse ist neu)
6. [ ] In der Prod-App registrieren → im SQL Editor dich selbst als Admin eintragen (Befehl aus A4.9)
7. [ ] **Demo-Konto für die Apple-Prüfung** registrieren → Claude füllt es mit Beispieldaten. Zugangsdaten nur in App Store Connect eintragen

### C2 Store-Einträge
- [ ] **Apple:**
  - Texte aus `docs/STORE_LISTING.md`, Bilder aus `docs/store/`
  - App-Datenschutz, Altersfreigabe und Prüfnotizen aus `docs/STORE_PRIVACY.md`
- [ ] **Google:**
  - Store-Eintrag aus `docs/STORE_LISTING.md`, Bilder aus `docs/store/`
  - Feature-Grafik 1024 × 500 → Claude erstellt sie

### C3 Veröffentlichen
- [ ] → Claude: „Release-Builds bauen“ (Prod-Backend, neue Build-Nummer)
- [ ] **Apple:** Build hochladen, der Version zuordnen → **Zur Prüfung einreichen**
- [ ] **Google:** nach den 14 Tagen **Zugriff auf Produktion beantragen** (Fragen zum Test beantworten), dann Release in Produktion übernehmen
- [ ] Nach Freigabe → Claude: „Ist live“ (Version taggen, nächstes Update vorbereiten)
- [ ] Ab dann regelmäßig: Meldungen in der App prüfen (Einstellungen → Meldungen prüfen)

---

## 8. Phase D · Später

| Thema | Was | Kosten |
|---|---|---|
| **Webseite** | Landingpage auf `getbooksquad.com` mit Store-Bildern, Download-Buttons und Rechtstexten. → Claude baut sie, Hosting über GitHub Pages | 0 € |
| **Marke anmelden** | DPMA oder EUIPO, wenn die App anläuft | 290–850 € |
| **Englische Version** | App-Texte, Store-Einträge und Rechtstexte auf Englisch, für den weltweiten Start | 0 € (ggf. Übersetzungsprüfung) |
| **Push-Benachrichtigungen** | Likes, Kommentare, neue Beiträge im Lesekreis. Braucht Firebase (kostenlos) und den Apple-Push-Schlüssel | 0 € |
| **Premium** | Erst Community aufbauen. Bei Einnahmen: Gewerbe, Steuern, Abo-Abwicklung über die Stores (15 % Provision im ersten Jahr für kleine Entwickler) | – |
| **Deutsche Buchbeschreibungen** | Zweite Buchquelle neben Open Library | 0 € |
