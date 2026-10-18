# Booksquad — Feature-Roadmap

Stand: Oktober 2026

## Status

| Bereich | Status |
|---------|--------|
| Auth (E-Mail, Passwort vergessen, Account löschen) | ✅ |
| Google / Apple Sign-In | 🟡 Code da, Dashboard-Config nötig |
| Profil, Avatar, Benutzername änderbar | ✅ |
| Visuelles Bücherregal (Lese ich / Ungelesen / Gelesen) + Wunschliste | ✅ |
| Feed, Posts, Bilder, Likes, Comments | ✅ |
| Folgen, Entdecken, Aktivität | ✅ |
| Gruppen (öffentlich/privat) | ✅ |
| Moderation (Melden/Blockieren) | ✅ |
| Legal-Links + Support | ✅ (URLs hosten) |
| Store-Release | 🟡 siehe `PUBLISH_PLAN.md` |

## Geplant (nach dem Start)

| Idee | Notiz |
|------|-------|
| **Direktnachrichten** | Privatchat zwischen Leuten, die sich gegenseitig folgen. Braucht Echtzeit (Supabase Realtime), Melden/Blockieren im Chat, Moderationsweg, Datenschutz-Ergänzung |
| **Regal-Widget** | Homescreen-Widget mit dem eigenen Regal (iOS WidgetKit, Android App Widget), Daten über eine geteilte App-Gruppe |
| Push-Benachrichtigungen | Likes, Kommentare, Lesekreis-Beiträge |
| Englische Version | App, Store, Rechtstexte |

## Nächster Schritt

1. Supabase-Migrationen → [`supabase/APPLY_MIGRATIONS.md`](supabase/APPLY_MIGRATIONS.md)
2. Testen → [`TESTING.md`](TESTING.md)
3. Feedback geben
4. Publish-Schritte → [`PUBLISH_PLAN.md`](PUBLISH_PLAN.md)
