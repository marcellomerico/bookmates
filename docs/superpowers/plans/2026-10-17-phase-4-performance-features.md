# Phase 4 — Performance & Features: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps (`- [ ]`).

**Goal:** Die App bleibt auch mit vielen Nutzern und Beiträgen schnell. Feeds laden seitenweise, Zähler kommen vom Server statt aus ganzen Tabellen, Likes reagieren sofort. Außerdem kommen zwei Community-Features dazu, die den Kaltstart erleichtern: eine Buch-Detailseite und Vorschläge zum Folgen im Onboarding.

**Architecture:**
- **Datenbank:** Keine neue Logik. Nur Indizes (Migration 9). Zählungen über PostgREST-Aggregate (`likes(count)`, `count: CountOption.exact`, `head`), Filter über `!inner`-Joins, Pagination per Cursor auf `created_at`.
- **Client:** Ein wiederverwendbarer seitenweiser Provider (`PagedPostsNotifier`) für Feed, Lesekreis-Beiträge und Profil-Beiträge. Optimistische Likes über einen gemeinsamen Override-State, damit alle Listen synchron bleiben.

**Tech Stack:** Flutter 3.44.5, Riverpod 2.6, supabase_flutter 2.16 (PostgREST v12 Aggregate), Open Library Works API.

## Entscheidungen
- Seitengröße 20, Cursor `created_at < letzter Eintrag` (stabil bei neuen Beiträgen; Duplikate bei gleichem Zeitstempel über `id`-Dedupe vermeiden).
- „Gefällt mir“-Status der eigenen Likes per zweiter, kleiner Abfrage pro Seite (`likes.select(post_id).eq(user_id).in(post_id, ids)`). Damit sinkt die Anzahl übertragener Zeilen von *Likes × Beiträge* auf *Beiträge*.
- Buch-Detailseite über die Open-Library-Werk-ID (`/books/:olid`), weil auch Suchergebnisse ohne Datenbank-Eintrag verlinkbar sein sollen.

## Nicht in Phase 4
- Push-Benachrichtigungen (braucht Firebase- und APNs-Konten) → eigene Phase vor oder nach dem Release
- Dark Mode, Lese-Fortschritt, Rezensionen mit Text → nach dem Release (Kandidaten für die Roadmap)

---

### Task 1 — Datenzugriffe effizient (Repositories + Migration 9)
- [ ] `supabase/migrations/20261017180000_feed_indexes.sql`: Indizes `posts (created_at desc)`, `posts (group_id, created_at desc)`, `posts (book_id, created_at desc)`, `user_books (book_id)` (falls nicht vorhanden), `likes (user_id, post_id)`. Auf Dev anwenden (Trockenlauf unnötig, nur Indizes), Advisor prüfen.
- [ ] `PostRepository`:
  - `_select` → `'*, profiles(*), books(*), likes(count), comments(count)'`
  - `getFeed` / `getPostsByAuthor` / Gruppen-Beiträge: Parameter `DateTime? before`, `int limit = 20` → `.lt('created_at', before)`
  - danach `_withLikedByMe(posts, userId)` über eine `likes`-Abfrage für die IDs der Seite
  - `Post.fromJson` liest Aggregate (`likes: [{count: n}]`) und fällt auf das alte Listenformat zurück
  - Tests für beide Formate
- [ ] `ProfileRepository.getStats`: drei Count-Abfragen (`count(CountOption.exact)` bzw. `select('id', head: true, count: ...)`) parallel per `Future.wait`.
- [ ] `ActivityRepository`: kein Laden aller eigenen Beiträge mehr. Likes und Kommentare über `posts!inner(author_id, content)` mit Filter `posts.author_id = me`, Ausschluss eigener Aktionen. Parallel per `Future.wait`.
- [ ] `GroupRepository.listGroups`:
  - `group_members(count)` statt aller Mitglieder; Mitgliedschaft des Nutzers über eine kleine Abfrage der eigenen `group_members`
  - Suche serverseitig (`ilike` auf Name, mit `sanitizeSearchTerm`), `limit 50`
  - `BookGroup.fromJson` unterstützt beide Formate (Test)
- [ ] `CachedNetworkImage` in Feed/Karten/Regal mit `memCacheWidth` (Breite × devicePixelRatio, gedeckelt).

### Task 2 — Pagination & optimistische Likes
- [ ] `lib/features/social/providers/paged_posts.dart`: `PagedPostsNotifier` (AutoDisposeFamilyAsyncNotifier, Schlüssel = Quelle: Feed, Lesekreis-ID oder Autor-ID). Zustand `PagedPosts(items, hasMore, loadingMore)`, Methoden `loadMore()` und `refresh()`. Blockierte Autoren filtert der Server bereits; das alte Client-Filtern entfällt, wo möglich.
- [ ] `feedProvider`, `groupPostsProvider`, `userPostsProvider` darauf umstellen. Screens (Home, Lesekreis-Detail, Profil, Fremdprofil): Endlos-Scroll (am Listenende `loadMore`), Lade-Indikator am Ende, Pull-to-refresh → `refresh()`.
- [ ] Optimistische Likes:
  - `likeOverridesProvider` (`Map<postId, (liked, count)>`)
  - `PostCard` zeigt Override vor Server-Wert, togglet sofort und ruft das Repository auf; bei Fehler Rollback plus SnackBar
  - keine Feed-Invalidierung mehr pro Like
  - Doppeltipp entprellen, solange ein Request läuft
- [ ] Alle Stellen, die nach Mutationen `feedProvider` invalidieren, rufen stattdessen `refresh()` des betroffenen Notifiers auf (oder `invalidate` der Family). grep `invalidate(feedProvider`.
- [ ] Tests: Notifier mit Fake-Repository (erste Seite, `loadMore` hängt an, `hasMore` false bei < 20, Dedupe), Like-Override (toggle, rollback).

### Task 3 — Buch-Detailseite
- [ ] `OpenLibraryRepository.getWork(olid)`: `https://openlibrary.org/works/<olid>.json` → Titel, Beschreibung (String oder `{value}`), Themen (max. 8), Cover-ID. Timeout 10 s, User-Agent `Booksquad/1.0 (support@getbooksquad.com)`. Test mit `MockClient`.
- [ ] `BookRepository`: `getByOpenLibraryId(olid)` (Datenbank-Buch oder null), `readerCount(bookId)` (Count auf `user_books`), `myEntry(bookId)`.
- [ ] Beiträge zum Buch über `PostRepository.getFeed(bookId:)` (seitenweise, Filter `book_id`).
- [ ] Screen `lib/features/books/presentation/book_detail_screen.dart`, Route `/books/:olid`:
  - Cover groß, Titel, Autor, „N Leser haben es im Regal“
  - Regal-Status-Auswahl (Will ich lesen / Lese ich / Gelesen) mit bestehendem `addToShelf`/Status-Update
  - Beschreibung (aufklappbar), Themen als Chips, „Beiträge zu diesem Buch“ (paged) mit EmptyState
  - Fehler- und Ladezustände über `state_views`
- [ ] Verlinken: Buch-Chip in `PostCard`, Regal-Einträge, Suchergebnisse in `book_search_screen` (Tipp auf den Eintrag öffnet die Detailseite, der Plus-Button bleibt).
- [ ] Widget-Test der Detailseite mit Fake-Providern.

### Task 4 — Onboarding: Lesern folgen
- [ ] Neuer Schritt im Onboarding nach der Genre-Auswahl: „Leser, die deinen Geschmack teilen“. Bis zu 10 Vorschläge aus `recommendByGenres` mit Folgen-Buttons (optimistisch), dazu „Lesekreise für dich“ (bis zu 5 öffentliche passend zu den Genres; sonst die neuesten) mit Beitreten. „Überspringen“ ist immer möglich.
- [ ] Leerzustand, wenn es noch keine Nutzer gibt („Du bist eine der ersten Personen hier – lade Freunde ein!“). Kein Fehler.
- [ ] Fortschrittsanzeige im Onboarding passt die Schrittzahl an.
- [ ] Widget-Test: Schritt rendert Vorschläge und reagiert auf Folgen.

### Task 5 — Abschluss
- [ ] Gesamt-Review (Opus), Fixes. Prüfen: keine N+1-Abfragen, keine ungebremsten Listen, Pagination-Randfälle.
- [ ] TESTING.md: Teil „Feed & Bücher“ (Endlos-Scroll, Like offline → Rollback, Buch-Detail aus Feed, Regal und Suche, Onboarding-Vorschläge).
- [ ] PR `phase-4/performance-features` → `main`, Auto-Fix an.

**Reihenfolge:** 1 → 2 → 3 → 4 → 5. Task 2 baut auf dem neuen Repository-Format aus Task 1 auf. Nach jedem Task: analyze und test über die Exit-Codes prüfen, Commit, Push.
