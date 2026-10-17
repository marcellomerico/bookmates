# Release-Checkliste (Marcello)

Alles, was Konten, Geld, Zugangsdaten oder rechtliche Verantwortung braucht. In dieser Reihenfolge abarbeiten; spätere Schritte bauen auf früheren auf. Wo **„→ Claude“** steht, sag Bescheid, dann übernimmt Claude den Rest.

Grobe Kosten: Apple 99 €/Jahr, Google einmalig 25 $, Supabase Pro ca. 25 $/Monat, Mail-Versand (SMTP) meist gratis im Einstiegstarif.

## 1. Konten und Adressen (Vorlauf: Tage)

- [ ] **Apple Developer Program** beitreten (Privatperson oder Firma; Firma braucht eine D-U-N-S-Nummer, das dauert länger). Team-ID `73W5K48926` ist im Projekt schon gesetzt. Bei einem anderen Konto die Team-ID nennen → Claude
- [ ] **Google Play Console** Konto anlegen. Neue private Konten müssen vor dem Produktionsstart **12 Testpersonen über 14 Tage** im geschlossenen Test haben. Früh anfangen
- [ ] **Support-Adresse** muss echt erreichbar sein. Im Code und in den Texten steht `support@bookmates.app`. Gehört dir die Domain nicht, eine andere Adresse nennen → Claude ersetzt sie überall
- [ ] **App-Name** in App Store Connect reservieren („Bookmates – Lesen mit Freunden“). Ist er vergeben, Alternative nennen → Claude passt die Store-Texte an

## 2. Rechtstexte (vor jedem öffentlichen Test)

- [ ] Platzhalter in `docs/legal/*.md` ausfüllen (Name, Anschrift, E-Mail, Fristen)
- [ ] Rechtlich prüfen lassen (Datenschutzerklärung, Nutzungsbedingungen, Impressum)
- [ ] Veröffentlichen nach `docs/RELEASE.md` → „Rechtstexte veröffentlichen“ (GitHub Pages, ein Befehl) → oder Claude Bescheid geben, dann baut und pusht Claude die Seiten

## 3. Produktions-Backend

- [ ] Supabase-Prod-Projekt anlegen: Frankfurt, Pro-Plan, AVV abschließen (`docs/SUPABASE_PRODUCTION.md` Schritt 1) → Projekt-Ref an Claude
- [ ] → Claude: Schema, Edge Function, Advisor-Checks (Schritte 2, 3, 6)
- [ ] Auth-Einstellungen im Dashboard (Schritt 4): E-Mail-Bestätigung, Redirect-URL `bookmates://auth-callback`, Leaked-Password-Schutz, **eigener SMTP-Versand**
- [ ] Google- und Apple-Login einrichten (`docs/GOOGLE_APPLE_AUTH.md`), danach die iOS-Client-ID nennen → Claude trägt den URL-Scheme in `Info.plist` ein
- [ ] Gleiches auch für das **Dev**-Projekt: Leaked-Password-Schutz einschalten (einziger offener Advisor-Hinweis)
- [ ] Prod-Werte in `.env` eintragen (nicht committen; `.env` ist ignoriert)
- [ ] In der Prod-App registrieren → Claude macht dich zum Admin (Schritt 5)
- [ ] Optional: Benachrichtigung bei neuen Meldungen (Database Webhook auf `reports` → Mail-Dienst). Ohne das Moderations-Queue regelmäßig in der App prüfen

## 4. Signieren

- [ ] **Android:** Upload-Keystore erzeugen und `android/key.properties` anlegen (`docs/RELEASE.md` → Android). Keystore und Passwörter sicher sichern; Verlust ist mit Play App Signing reparierbar, aber mühsam
- [ ] **Android:** Flutter ein JDK ≤ 25 geben: `flutter config --jdk-dir /Users/marcello/Library/Java/JavaVirtualMachines/openjdk-23.0.2/Contents/Home`
- [ ] **iOS:** In Xcode (Runner → Signing & Capabilities) mit dem Apple-Konto anmelden, „Automatically manage signing“ an. App-ID `com.bookmates.bookmates` mit „Sign in with Apple“ wird dabei angelegt

## 5. Store-Einträge anlegen

- [ ] App Store Connect: neue App, Bundle-ID `com.bookmates.bookmates`, Texte aus `docs/STORE_LISTING.md`
- [ ] Play Console: neue App, Texte aus `docs/STORE_LISTING.md`
- [ ] Datenschutz-Angaben, Altersfreigabe, Data Safety aus `docs/STORE_PRIVACY.md`
- [ ] **Demo-Konto für Apple Review** in Prod anlegen (mit ein paar Beiträgen, einem öffentlichen und einem privaten Lesekreis); Zugangsdaten nur in App Store Connect eintragen, nicht im Repo
- [ ] Screenshots nach dem Plan in `docs/STORE_LISTING.md` (iOS 6,9", Android Telefon, Play-Feature-Grafik)

## 6. Testbuilds

**iOS → TestFlight**
1. `BOOKMATES_PROD_REF=<ref> tool/build_release.sh ios`
2. `build/ios/ipa/*.ipa` mit der App **Transporter** hochladen (oder `open build/ios/archive/Runner.xcarchive` → Xcode Organizer → Distribute App)
3. In App Store Connect → TestFlight: Build erscheint nach der Verarbeitung (10–30 Min.). Interne Tester (bis 100, ohne Review) hinzufügen. Externe Tester brauchen eine kurze Beta-Review
4. Jeder weitere Upload: Build-Nummer erhöhen (`tool/build_release.sh ios 2`, dann 3 …)

**Android → Internal Testing**
1. `BOOKMATES_PROD_REF=<ref> tool/build_release.sh android`
2. Play Console → Testen → Interner Test → Neuen Release erstellen → `build/app/outputs/bundle/release/app-release.aab` hochladen. Play App Signing bestätigen
3. Tester-Liste (E-Mails) anlegen, Opt-in-Link an Tester schicken
4. Danach **geschlossener Test** mit mindestens 12 Personen über 14 Tage (Pflicht für neue private Konten), erst dann Produktion beantragen

## 7. Auf echten Geräten testen

- [ ] `TESTING.md`: Teile D–M, dazu die UI-Checks (Teil J) und „Feed & Bücher“, auf je einem iPhone und einem Android-Gerät
- [ ] Besonders: Registrierung mit Bestätigungsmail, Passwort-Reset-Link öffnet die App, Google-/Apple-Login, Foto-Upload, Konto löschen
- [ ] Gefundene Fehler an Claude geben

## 8. Einreichen

- [ ] iOS: Build in App Store Connect der Version zuordnen → Zur Prüfung einreichen
- [ ] Android: Release vom geschlossenen Test in Produktion übernehmen
- [ ] Nach Freigabe: Version taggen (`git tag v1.0.0+<build>` und pushen) → oder Claude
