# Store-Einträge (Deutsch)

Texte zum Kopieren in App Store Connect und die Play Console. Jeder Text mit Limit steht in einem `text`-Block unter einer Überschrift `(max N)`. `python3 tool/check_store_listing.py` prüft die Längen.

Ton: warm, einladend, du-Form, keine Superlative ohne Beleg. Keine Preise oder „kostenlos für immer“, weil später Premium-Funktionen möglich sind.

---

## App Store (iOS)

### App-Name (max 30)
```text
Booksquad – Lesen mit Freunden
```

### Untertitel (max 30)
```text
Bücherregal & Lesekreise
```

### Werbetext (max 170)
```text
Teile, was du liest, finde Menschen mit deinem Buchgeschmack und tausch dich in Lesekreisen über deine Lieblingsbücher aus.
```

### Keywords (max 100)
Kommagetrennt, ohne Leerzeichen. Wörter aus Name und Untertitel nicht wiederholen (Apple wertet sie ohnehin).
```text
buch,bücher,leseliste,rezension,buchclub,lesezeichen,zitate,leseratte,roman,krimi,fantasy,community
```

### Beschreibung (max 4000)
```text
Booksquad ist die Community für alle, die gerne lesen. Halte fest, was du liest, entdecke neue Bücher über Menschen mit ähnlichem Geschmack und sprich in Lesekreisen über das, was dich bewegt.

DEIN BÜCHERREGAL
• Sortiere Bücher nach „Will ich lesen“, „Lese ich gerade“ und „Gelesen“
• Bewerte Bücher mit bis zu fünf Sternen
• Finde Bücher schnell über die Suche mit Millionen Titeln aus Open Library

TEILEN UND AUSTAUSCHEN
• Schreib Rezensionen, Empfehlungen, Diskussionen oder teile dein Lieblingszitat
• Füg Fotos hinzu und verknüpf deinen Beitrag mit einem Buch
• Like und kommentier die Beiträge anderer Leserinnen und Leser

LESEKREISE
• Gründe einen Lesekreis zu deinem Lieblingsgenre oder tritt einem bei
• Private Lesekreise nur mit Einladungscode, ideal für Freundeskreis oder Buchclub
• Eigener Feed pro Lesekreis

ENTDECKEN
• Leserinnen und Leser mit deinem Geschmack, passend zu deinen Lieblingsgenres
• Buchseiten mit Beschreibung, Themen und allen Beiträgen zum Buch
• Folge anderen und sieh ihre Beiträge in deinem Feed

SICHER UND RESPEKTVOLL
• Inhalte und Personen melden oder blockieren, direkt aus der App
• Gemeldete Inhalte werden geprüft
• Konto und alle Daten jederzeit in der App löschen
• Keine Werbung, kein Verkauf deiner Daten

Booksquad wird in Deutschland entwickelt und ist noch jung. Über Feedback an support@getbooksquad.com freuen wir uns sehr.
```

### Neuerungen in dieser Version (max 4000)
```text
Willkommen bei Booksquad! Das ist die erste Version. Wir freuen uns auf dein Feedback.
```

### Weitere Angaben
| Feld | Wert |
|------|------|
| Primäre Kategorie | Soziale Netze |
| Sekundäre Kategorie | Bücher |
| Altersfreigabe | 12+ (nutzergenerierte Inhalte, siehe `docs/STORE_PRIVACY.md`) |
| Support-URL | `https://getbooksquad.com/` (nach Veröffentlichung der Seiten) |
| Datenschutz-URL | `https://getbooksquad.com/privacy.html` |
| Copyright | `2026 <Name aus dem Impressum>` |
| Preis | Gratis |

---

## Google Play (Android)

### App-Name (max 30)
```text
Booksquad – Lesen mit Freunden
```

### Kurzbeschreibung (max 80)
```text
Bücherregal, Rezensionen und Lesekreise: teile, was du liest.
```

### Ausführliche Beschreibung (max 4000)
Gleicher Text wie die App-Store-Beschreibung oben. Play erlaubt keine Emojis im Titel und keine Ranking-Behauptungen („Nr. 1“); beides kommt im Text nicht vor.

### Weitere Angaben
| Feld | Wert |
|------|------|
| Kategorie | Soziale Netzwerke |
| Tags | Bücher, Lesen, Community |
| E-Mail | support@getbooksquad.com |
| Datenschutz-URL | wie App Store |
| Web-Löschseite | `https://getbooksquad.com/delete-account.html` |
| Inhaltsfreigabe | Fragebogen: nutzergenerierte Inhalte mit Moderation, Melden und Blockieren (Ergebnis meist USK 12 / PEGI 12) |
| Zielgruppe | 16+ (unter 16 nicht Zielgruppe, passt zu den Nutzungsbedingungen) |
| Werbung | Nein |

---

## Screenshots

Größen:
- **iOS:** 6,9" (1320 × 2868) ist Pflicht. Daraus skaliert Apple die kleineren Größen.
- **Android:** Telefon mindestens 1080 × 1920. Dazu eine Feature-Grafik 1024 × 500.

Mit einem Demo-Konto und gefüllten Demo-Daten aufnehmen (echte Buchcover, keine echten Personen). Reihenfolge und Bildtexte:

| # | Screen | Bildtext oben |
|---|--------|---------------|
| 1 | Feed mit Beiträgen | Sieh, was deine Freunde lesen |
| 2 | Bücherregal (Profil) | Dein Regal, immer dabei |
| 3 | Buch-Detailseite | Alles zu einem Buch auf einen Blick |
| 4 | Lesekreis-Detail | Lesekreise für jedes Genre |
| 5 | Beitrag erstellen (Zitat) | Teile Rezensionen und Zitate |
| 6 | Entdecken | Finde Menschen mit deinem Geschmack |

Bildtexte in Source Serif 4, Bordeaux `#7B3140` auf Creme `#F7F2E8`, passend zur App.

Feature-Grafik (Play): App-Icon links, Schriftzug „Booksquad“ in dunklem Gold `#85661A`, Untertitel „Lesen mit Freunden“, Hintergrund Creme.
