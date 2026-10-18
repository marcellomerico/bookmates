# E-Mail-Vorlagen (Supabase Auth)

Deutsche Vorlagen im Booksquad-Design. Einfügen im Supabase-Dashboard unter
**Authentication → Emails → Templates**, jeweils Betreff und den kompletten Inhalt der Datei („Source“).

| Vorlage im Dashboard | Betreff | Datei |
|---|---|---|
| Confirm signup | `Bestätige deine E-Mail für Booksquad` | `confirm-signup.html` |
| Reset password | `Dein neues Passwort für Booksquad` | `reset-password.html` |
| Change email address | `Bestätige deine neue E-Mail-Adresse` | `change-email.html` |

Das Logo kommt von `https://booksquad.de/mail-icon.png` (liegt in `site/`).
Absender und SMTP: Authentication → Emails → SMTP Settings (`support@booksquad.de`, IONOS).
Gilt für Dev- und Prod-Projekt gleichermaßen.
