# Store-Angaben: Datenschutz, Altersfreigabe, Review

Antworten für App Store Connect und Google Play Console, Stand Oktober 2026. Grundlage ist das tatsächliche Verhalten der App (siehe `docs/legal/PRIVACY.md`). Die Angaben müssen zur veröffentlichten Datenschutzerklärung passen.

## 1. App Store — App-Datenschutz („Nutrition Label“)

**Tracking:** Nein. Die App nutzt keine Daten, um Nutzer über Apps oder Websites anderer Unternehmen hinweg zu verfolgen. Es gibt keine Werbung und keine Analytics.

| Datentyp (Apple) | Erhoben | Mit Identität verknüpft | Tracking | Zweck |
|---|---|---|---|---|
| Kontaktinformationen → E-Mail-Adresse | Ja | Ja | Nein | App-Funktionalität |
| Kontaktinformationen → Name (Anzeigename) | Ja | Ja | Nein | App-Funktionalität |
| Nutzerinhalte → Fotos oder Videos | Ja | Ja | Nein | App-Funktionalität |
| Nutzerinhalte → Andere Nutzerinhalte (Beiträge, Kommentare, Bücherregal) | Ja | Ja | Nein | App-Funktionalität |
| Kennungen → Nutzer-ID | Ja | Ja | Nein | App-Funktionalität |

Nicht erhoben: Standort (GPS wird aus Fotos entfernt), Kontakte, Browserverlauf, Suchverlauf (Buchsuchen werden nicht gespeichert), Kauf-, Finanz-, Gesundheits- und Diagnosedaten.

Diese Angaben entsprechen `ios/Runner/PrivacyInfo.xcprivacy`.

## 2. Google Play — Datensicherheit

- **Werden Daten erhoben oder geteilt?** Erhoben: ja. Geteilt: nein. Die Weitergabe an Auftragsverarbeiter (Supabase) und die nutzerinitiierte Anzeige für andere Nutzer gelten nach Play-Definition nicht als „Teilen“.
- **Verschlüsselung bei der Übertragung:** Ja (TLS).
- **Löschanfrage möglich:** Ja, in der App und per Web: `https://marcellomerico.github.io/bookmates/delete-account.html`.
- **Kontoerstellung:** E-Mail und Passwort. Optional „Mit Apple anmelden“ und „Mit Google anmelden“, sobald konfiguriert.

| Kategorie → Datentyp | Erhoben | Pflicht/optional | Zweck |
|---|---|---|---|
| Persönliche Daten → E-Mail-Adresse | Ja | Pflicht | Kontoverwaltung, App-Funktionalität |
| Persönliche Daten → Name | Ja | Optional (Anzeigename) | App-Funktionalität |
| Persönliche Daten → Nutzer-IDs | Ja | Pflicht | Kontoverwaltung, App-Funktionalität |
| Fotos und Videos → Fotos | Ja | Optional | App-Funktionalität |
| App-Aktivität → Sonstige nutzergenerierte Inhalte | Ja | Optional | App-Funktionalität |
| App-Aktivität → Sonstige Aktionen (Likes, Folgen, Meldungen) | Ja | Optional | App-Funktionalität, Betrugsprävention/Sicherheit |

## 3. Altersfreigabe

Die App enthält **nutzergenerierte Inhalte** und **Interaktion zwischen Nutzern** (Kommentare, Gruppen). Es gibt kein Chat-Feature mit Fremden und keinen Webbrowser. Folgende Schutzmechanismen sind vorhanden: Melden, Blockieren, Auto-Ausblenden nach Meldungen, Moderation, Null-Toleranz-Regeln und Spam-Limits.

- **Apple (Altersfreigabe-Fragebogen):** Alle Inhaltskategorien „Keine“. Bei „Nutzergenerierte Inhalte / uneingeschränkter Zugriff“ wahrheitsgemäß angeben, dass Nutzerinhalte existieren und moderiert werden. Das Ergebnis liegt voraussichtlich bei **12+**. Stuft Apple höher ein, ist das zu akzeptieren. Mindestalter laut Nutzungsbedingungen: 16.
- **Google Play (IARC):** Interaktive Elemente „Nutzer interagieren“ und „Nutzergenerierte Inhalte teilen“ angeben. Keine Gewalt, keine sexuellen Inhalte, keine Glücksspiele. Zielgruppe: ab 16, nicht für Kinder. Damit gelten die Familienrichtlinien nicht.

## 4. Notizen für das App Review (Apple)

```
Demo account: [E-Mail] / [Passwort]  (contains sample posts, a public and a private group)

Bookmates is a community app for readers. User-generated content is moderated:
- Report: tap "…" on any post, comment or profile → "Melden".
- Block: tap "…" on a post, comment or profile → "Blockieren". Blocked users can no longer see
  or interact with the blocker's content (enforced server-side).
- Content reported by 3 users is hidden automatically until reviewed.
- Moderators review reports in-app (Profil → Einstellungen → "Meldungen prüfen") within 24 hours and
  can hide or delete content; accounts are suspended by the moderator in the backend.
- Users must accept the Terms of Use (zero tolerance for objectionable content)
  at sign-up.
- Account deletion: Profil → Einstellungen → "Konto löschen" (deletes all data and images).
Contact: [support@bookmates.app]
```

## 5. Pflichtfelder in den Stores

| Feld | Wert |
|---|---|
| Datenschutz-URL | `https://marcellomerico.github.io/bookmates/privacy.html` (nach Veröffentlichung) |
| Support-URL / -E-Mail | `[support@bookmates.app]` bzw. Index-Seite |
| Nutzungsbedingungen (EULA) | `https://marcellomerico.github.io/bookmates/terms.html` |
| Web-Löschseite (Play) | `https://marcellomerico.github.io/bookmates/delete-account.html` |
| Marketing-URL | optional |
| Kategorie | Soziale Netzwerke (Alternative: Bücher) |
