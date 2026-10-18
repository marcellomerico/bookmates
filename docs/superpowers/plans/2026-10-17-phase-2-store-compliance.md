# Phase 2 — Store-Compliance & Moderation: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps (`- [ ]`).

**Goal:** Booksquad erfüllt die Store-Anforderungen für Apps mit nutzergenerierten Inhalten (Apple 1.2, 5.1.1, Privacy Manifest; Google Play UGC- und Data-Safety-Richtlinien). Dazu kommen ein funktionierender Moderations-Workflow, Spam-Bremsen und DSGVO-taugliche Rechtstexte.

**Architecture:**
- **Datenbank:** Migration 7 legt die Admin-Rolle in `private.admins` ab. Die App kann sie nicht setzen, die API nicht erreichen. Dazu kommen ausgeblendete Inhalte (`hidden_at`), ein Report-Status, Auto-Hide ab 3 Meldungen, Admin-RPCs und Rate-Limit-Trigger.
- **Client:** Moderations-Queue für Admins, Zustimmung zu den Nutzungsbedingungen bei der Registrierung, aufgeräumte Social-Login-Buttons.
- **Plattform:** Privacy Manifest, gebündelte Fonts, Rechtstexte als statische Seiten (noch nicht veröffentlicht) und ein Store-Fragebogen-Dokument.

**Tech Stack:** Flutter 3.44.5, Riverpod 2.6, Supabase (Postgres 17), sign_in_with_apple, google_fonts (offline), Ruby `xcodeproj` (über CocoaPods vorhanden).

## Entscheidungen (Marcello, 17.10.2026)
- Source-Serif-4-TTFs aus google/fonts herunterladen und bündeln: **ja**
- Rechtstexte als Seiten bauen, **erst nach deiner Prüfung veröffentlichen**
- Den bestehenden Dev-Account zum **Admin** machen
- Dev-Supabase-Aktionen ohne Rückfrage, keine Claude-Attribution, nach jedem Task committen und pushen

## Bleibt bei Marcello (nicht automatisierbar)
- Impressum: Name, Adresse, Kontakt. Rechtliche Prüfung der Texte. Veröffentlichung (GitHub Pages oder eigene Domain).
- Google Cloud OAuth-Client-IDs plus Supabase-Provider (Google). Apple Service ID plus Key (Apple-Provider).
- Supabase-Dashboard: Redirect-URL `booksquad://auth-callback`, Leaked-Password-Schutz, Auth-Rate-Limits/CAPTCHA.
- Demo-Account für das Apple Review (Accounts legt Claude im gehosteten Supabase nicht an).
- Apple-Developer- und Play-Console-Konten, Store-Formulare mit den Antworten aus `docs/STORE_PRIVACY.md`.

---

### Task 1: Migration 7 — Moderation & Rate Limits

**Files:** Create `supabase/migrations/20261017120000_moderation_and_rate_limits.sql`. Modify `supabase/tests/rls_smoke.sql`.

- [ ] **Step 1: Migration schreiben** (komplett):

```sql
-- Phase 2: moderation workflow + rate limits.
-- Admins are managed via SQL only:  insert into private.admins (user_id) values ('<auth uid>');

create table if not exists private.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
revoke all on private.admins from public, anon, authenticated;

create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from private.admins where user_id = auth.uid());
$$;
revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

create or replace function public.am_i_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select private.is_admin();
$$;
revoke all on function public.am_i_admin() from public, anon;
grant execute on function public.am_i_admin() to authenticated;

-- ---------- Hidden content (auto-hide or admin); authors still see their own ----------
alter table public.posts add column if not exists hidden_at timestamptz;
alter table public.comments add column if not exists hidden_at timestamptz;

create or replace function private.can_view_post(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.posts p
    where p.id = pid
      and (p.group_id is null or private.can_view_group(p.group_id))
      and not private.is_blocked_with(p.author_id)
      and (p.hidden_at is null or p.author_id = auth.uid())
  );
$$;

drop policy if exists "Posts visible by visibility rules" on public.posts;
create policy "Posts visible by visibility rules" on public.posts
  for select to authenticated
  using (
    (group_id is null or private.can_view_group(group_id))
    and not private.is_blocked_with(author_id)
    and (hidden_at is null or author_id = auth.uid())
  );

drop policy if exists "Comments visible with post" on public.comments;
create policy "Comments visible with post" on public.comments
  for select to authenticated
  using (
    private.can_view_post(post_id)
    and not private.is_blocked_with(author_id)
    and (hidden_at is null or author_id = auth.uid())
  );

-- Only definer code (admin RPCs, auto-hide trigger) may change hidden_at.
create or replace function private.protect_hidden_at()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.hidden_at is distinct from old.hidden_at and current_user in ('authenticated', 'anon') then
    raise exception 'hidden_at is managed by moderation' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists posts_protect_hidden_at on public.posts;
create trigger posts_protect_hidden_at before update on public.posts
  for each row execute function private.protect_hidden_at();

create or replace function private.clear_hidden_on_insert()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.hidden_at := null;
  end if;
  return new;
end;
$$;
drop trigger if exists posts_clear_hidden on public.posts;
create trigger posts_clear_hidden before insert on public.posts
  for each row execute function private.clear_hidden_on_insert();
drop trigger if exists comments_clear_hidden on public.comments;
create trigger comments_clear_hidden before insert on public.comments
  for each row execute function private.clear_hidden_on_insert();

-- ---------- Reports workflow ----------
alter table public.reports
  add column if not exists status text not null default 'open',
  add column if not exists resolved_at timestamptz,
  add column if not exists resolved_by uuid references auth.users(id) on delete set null;
alter table public.reports
  add constraint reports_status_valid check (status in ('open', 'dismissed', 'actioned'));

-- One report per reporter and target (keeps auto-hide counts honest).
create unique index if not exists reports_unique_post on public.reports (reporter_id, post_id) where post_id is not null;
create unique index if not exists reports_unique_comment on public.reports (reporter_id, comment_id) where comment_id is not null;
create unique index if not exists reports_unique_user on public.reports (reporter_id, reported_user_id)
  where post_id is null and comment_id is null and reported_user_id is not null;
create index if not exists reports_open_idx on public.reports (created_at) where status = 'open';

create or replace function private.auto_hide_reported()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.post_id is not null and (
    select count(distinct reporter_id) from public.reports
    where post_id = new.post_id and status = 'open') >= 3 then
    update public.posts set hidden_at = now() where id = new.post_id and hidden_at is null;
  end if;
  if new.comment_id is not null and (
    select count(distinct reporter_id) from public.reports
    where comment_id = new.comment_id and status = 'open') >= 3 then
    update public.comments set hidden_at = now() where id = new.comment_id and hidden_at is null;
  end if;
  return new;
end;
$$;
drop trigger if exists reports_auto_hide on public.reports;
create trigger reports_auto_hide after insert on public.reports
  for each row execute function private.auto_hide_reported();

-- ---------- Admin RPCs ----------
-- Returns nothing for non-admins.
create or replace function public.admin_open_reports()
returns table (
  report_id uuid, reported_at timestamptz, reason text, reporter_username text,
  target_user_id uuid, target_username text, target_post_id uuid, target_comment_id uuid,
  content text, content_hidden boolean
)
language sql stable security definer set search_path = public as $$
  select r.id, r.created_at, r.reason, rp.username,
         coalesce(r.reported_user_id, c.author_id, p.author_id), tu.username,
         r.post_id, r.comment_id,
         coalesce(c.content, p.content),
         coalesce(c.hidden_at, p.hidden_at) is not null
  from public.reports r
  left join public.profiles rp on rp.id = r.reporter_id
  left join public.comments c on c.id = r.comment_id
  left join public.posts p on p.id = r.post_id
  left join public.profiles tu on tu.id = coalesce(r.reported_user_id, c.author_id, p.author_id)
  where private.is_admin() and r.status = 'open'
  order by r.created_at;
$$;
revoke all on function public.admin_open_reports() from public, anon;
grant execute on function public.admin_open_reports() to authenticated;

-- p_action: 'dismiss' (restore content), 'hide', 'delete'. Resolves all open reports on the same target.
create or replace function public.admin_resolve_report(p_report_id uuid, p_action text)
returns void language plpgsql security definer set search_path = public as $$
declare
  r public.reports%rowtype;
begin
  if not private.is_admin() then
    raise exception 'Not authorized' using errcode = '42501';
  end if;
  if p_action not in ('dismiss', 'hide', 'delete') then
    raise exception 'Invalid action' using errcode = '22023';
  end if;
  select * into r from public.reports where id = p_report_id for update;
  if not found then
    raise exception 'Report not found' using errcode = 'P0002';
  end if;

  -- Resolve first: deleting content nulls reports.post_id/comment_id (on delete set null).
  update public.reports
  set status = case when p_action = 'dismiss' then 'dismissed' else 'actioned' end,
      resolved_at = now(), resolved_by = auth.uid()
  where id = r.id
     or (status = 'open' and (
           (r.comment_id is not null and comment_id = r.comment_id)
        or (r.comment_id is null and r.post_id is not null and post_id = r.post_id and comment_id is null)));

  if p_action = 'hide' then
    update public.comments set hidden_at = coalesce(hidden_at, now()) where id = r.comment_id;
    update public.posts set hidden_at = coalesce(hidden_at, now())
      where id = r.post_id and r.comment_id is null;
  elsif p_action = 'delete' then
    delete from public.comments where id = r.comment_id;
    delete from public.posts where id = r.post_id and r.comment_id is null;
  else
    update public.comments set hidden_at = null where id = r.comment_id;
    update public.posts set hidden_at = null where id = r.post_id and r.comment_id is null;
  end if;
end;
$$;
revoke all on function public.admin_resolve_report(uuid, text) from public, anon;
grant execute on function public.admin_resolve_report(uuid, text) to authenticated;

-- ---------- Rate limits (raise 'rate_limit'; client shows a friendly message) ----------
create or replace function private.enforce_rate_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  n int;
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;
  if tg_table_name = 'posts' then
    select count(*) into n from public.posts
    where author_id = new.author_id and created_at > now() - interval '10 minutes';
    if n >= 10 then raise exception 'rate_limit' using hint = 'posts'; end if;
  elsif tg_table_name = 'comments' then
    select count(*) into n from public.comments
    where author_id = new.author_id and created_at > now() - interval '10 minutes';
    if n >= 30 then raise exception 'rate_limit' using hint = 'comments'; end if;
  elsif tg_table_name = 'reports' then
    select count(*) into n from public.reports
    where reporter_id = new.reporter_id and created_at > now() - interval '1 day';
    if n >= 20 then raise exception 'rate_limit' using hint = 'reports'; end if;
  elsif tg_table_name = 'groups' then
    select count(*) into n from public.groups
    where creator_id = new.creator_id and created_at > now() - interval '1 day';
    if n >= 5 then raise exception 'rate_limit' using hint = 'groups'; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists posts_rate_limit on public.posts;
create trigger posts_rate_limit before insert on public.posts for each row execute function private.enforce_rate_limit();
drop trigger if exists comments_rate_limit on public.comments;
create trigger comments_rate_limit before insert on public.comments for each row execute function private.enforce_rate_limit();
drop trigger if exists reports_rate_limit on public.reports;
create trigger reports_rate_limit before insert on public.reports for each row execute function private.enforce_rate_limit();
drop trigger if exists groups_rate_limit on public.groups;
create trigger groups_rate_limit before insert on public.groups for each row execute function private.enforce_rate_limit();

create index if not exists posts_author_created_idx on public.posts (author_id, created_at);
create index if not exists comments_author_created_idx on public.comments (author_id, created_at);
```

- [ ] **Step 2: RLS-Smoke-Test erweitern.** Ergänzungen in `supabase/tests/rls_smoke.sql`. Die Fixtures laufen als postgres, also ohne Rate-Limit.
  - Fixture: `insert into private.admins (user_id) values (<alice>)`.
  - Neuer Block **als BOB, CAROL, ERIN**: Jeder meldet Alices öffentlichen Post `…2b0` mit Grund 'spam' (Claims pro Insert wechseln). Danach **als postgres**: `posts.hidden_at` von `…2b0` ist nicht null (Auto-Hide).
    - Achtung Reihenfolge: Bob ist später von Alice blockiert. Alles, was Bob melden soll, muss **vor** dem Block passieren. Sinnvoll ist ein eigener Post `…2d0` von Alice nur für den Moderationstest.
  - **als ERIN** (nicht Autorin): sieht `…2d0` nicht mehr.
  - **als ALICE** (Autorin): sieht `…2d0` weiterhin. `update posts set hidden_at = null where id = …2d0` → `insufficient_privilege` (protect_hidden_at).
  - Ein Insert mit gesetztem `hidden_at` als User wird genullt.
  - **als CAROL**: zweite Meldung desselben Posts → `unique_violation`.
  - **als ERIN** (kein Admin): `select count(*) from admin_open_reports()` = 0, `admin_resolve_report(..., 'dismiss')` → `insufficient_privilege`.
  - **als ALICE** (Admin): `admin_open_reports()` liefert ≥ 3 Zeilen. `admin_resolve_report(<eine report id>, 'dismiss')` → alle offenen Reports zu `…2d0` stehen auf 'dismissed', und `hidden_at` ist null.
  - Rate-Limit **als ERIN**: 10 eigene Posts in einer Schleife, der 11. → Exception mit der Message 'rate_limit'. Abfangen mit `when raise_exception then if sqlerrm <> 'rate_limit' then raise; end if;`.
  - Privilegien: `has_function_privilege('anon','public.admin_open_reports()','execute')` ist false. `has_table_privilege('authenticated','private.admins','select')` ist false.

- [ ] **Step 3: Review** (Security-Auditor, Opus). Fixes nach Review.
- [ ] **Step 4: Auf Dev anwenden** (`apply_migration`). RLS-Test per `execute_sql` → `ALL RLS CHECKS PASSED`. Rollback prüfen (keine `@rls.test`-User übrig).
- [ ] **Step 5: Admin setzen:** `insert into private.admins (user_id) select id from auth.users;` (genau 1 User auf Dev, vorher zählen).
- [ ] **Step 6: Advisor** security → keine neuen Warnungen außer den bewusst öffentlichen RPCs.
- [ ] **Step 7: Commit + Push.**

### Task 2: Client — Moderations-Queue, ausgeblendete Inhalte, Doppelmeldungen

**Files:** `lib/models/moderation_report.dart` (neu), `lib/repositories/moderation_repository.dart`, `lib/features/social/providers/social_providers.dart`, `lib/features/moderation/presentation/moderation_queue_screen.dart` (neu), `lib/core/router/app_router.dart` (Route `/moderation`), `lib/features/profile/presentation/profile_screen.dart`, `lib/models/post.dart` (`hiddenAt` für Post und Comment), `lib/core/widgets/post_card.dart`, `lib/core/widgets/moderation_actions.dart`, Tests.

- [ ] **Model** `ModerationReport` mit `fromJson` für die Spalten von `admin_open_reports` (report_id, reported_at, reason, reporter_username, target_user_id, target_username, target_post_id, target_comment_id, content, content_hidden). Test zuerst (`test/models/moderation_report_test.dart`).
- [ ] **Repository:**
  - `Future<bool> isAdmin()` → `rpc('am_i_admin') == true`
  - `Future<List<ModerationReport>> openReports()` → `rpc('admin_open_reports')`
  - `Future<void> resolveReport(String reportId, String action)` → `rpc('admin_resolve_report', params: {'p_report_id': .., 'p_action': ..})`
  - `reportContent` fängt `PostgrestException` mit code `23505` ab und wirft `AppAuthException('Du hast das bereits gemeldet.')`.
- [ ] **Provider:**
  - `isAdminProvider`: `FutureProvider<bool>`, watcht `currentUserProvider`, false ohne User, false bei Fehler.
  - `openReportsProvider`: `FutureProvider.autoDispose<List<ModerationReport>>`.
- [ ] **Screen** `ModerationQueueScreen` (Titel „Meldungen“):
  - RefreshIndicator plus ListView von Cards: Grund, „gemeldet von @x · vor …“ (`formatRelativeTime`), Ziel „@user“, Inhaltsauszug (max. 4 Zeilen), Badge „ausgeblendet“ falls `content_hidden`.
  - Buttons „Verwerfen“, „Ausblenden“, „Löschen“. Löschen mit Bestätigungsdialog.
  - Nach einer Aktion: invalidate `openReportsProvider`, `feedProvider` und `postDetailProvider`. Fehler zeigen eine SnackBar über `authErrorMessage`.
  - Empty State „Keine offenen Meldungen 🎉“. Ausblenden und Löschen nur, wenn ein Post oder Kommentar das Ziel ist; bei reinen User-Meldungen nur „Erledigt“ (= 'hide', bewirkt nichts am Inhalt).
- [ ] **Profil:** Wenn `isAdminProvider` true ist: `OutlinedButton.icon(Icons.shield_outlined, 'Meldungen prüfen')` → `context.push('/moderation')`, platziert über „Support kontaktieren“.
- [ ] **Post/Comment-Modelle:** `hiddenAt` aus `hidden_at`. `PostCard` zeigt bei `hiddenAt != null` einen dezenten Hinweis „Ausgeblendet nach Meldungen – nur für dich sichtbar“.
- [ ] **Melden-Dialog:** Nach Erfolg kommt die SnackBar „Danke für deine Meldung. Wir prüfen sie zeitnah.“. Bei `AppAuthException` deren Text.
- [ ] **Tests:**
  - Model-Test
  - Widget-Test `ModerationQueueScreen` mit überschriebenem `openReportsProvider` (Liste rendert, Empty State)
  - Post-Model-Test für `hidden_at`
- [ ] analyze + test, Review, Commit, Push.

### Task 3: Rate-Limit-Meldungen im UI
- [ ] In `authErrorMessage` vor dem generischen Fallback: `PostgrestException` mit `message == 'rate_limit'` → „Zu viele Aktionen in kurzer Zeit. Bitte warte einen Moment.“ Test in `auth_error_message_test.dart`.
- [ ] Die festen Fehler-SnackBars beim Post erstellen, Kommentar senden, Gruppe erstellen und Melden zeigen bei Rate-Limit diesen Text, sonst die bisherige Meldung. Kleiner Helper `bool isRateLimit(Object e)` in `auth_provider.dart`.
- [ ] analyze + test, Commit, Push.

### Task 4: Zustimmung zu Nutzungsbedingungen (Apple 1.2 EULA)
- [ ] `register_screen.dart`: Checkbox-Zeile „Ich akzeptiere die Nutzungsbedingungen und die Datenschutzerklärung“. Beide Begriffe sind antippbare Links über `launch_utils` mit `AppConfig.termsUrl` und `privacyPolicyUrl`. Registrieren ist deaktiviert oder zeigt einen Fehler, solange sie nicht angehakt ist.
- [ ] `AuthRepository.signUp`: Metadaten zusätzlich `'terms_accepted_at': DateTime.now().toUtc().toIso8601String()`.
- [ ] `login_screen.dart` unter den Social-Buttons: kleiner Text „Mit der Anmeldung akzeptierst du unsere Nutzungsbedingungen und Datenschutzerklärung.“ mit denselben Links.
- [ ] Widget-Test: Registrieren ohne Haken → Fehlertext, kein Repository-Aufruf (Fake-`AuthRepository` über Provider-Override).
- [ ] analyze + test, Review, Commit, Push.

### Task 5: Social-Login aufräumen
- [ ] `social_sign_in_buttons.dart`:
  - Google-Button **nur** anzeigen, wenn `Env.isGoogleConfigured`. Der Entwickler-Hinweis entfällt komplett.
  - Apple-Button (nur iOS) als offizieller `SignInWithAppleButton(text: 'Mit Apple anmelden', style: SignInWithAppleButtonStyle.black, onPressed: …)`, Höhe 48, Radius passend zum Theme.
  - Ohne irgendeinen Social-Button wird der ganze Bereich inkl. Trenner ausgeblendet.
- [ ] Simulator-Screenshot des Login-Screens zur Kontrolle.
- [ ] analyze + test, Commit, Push.

### Task 6: iOS Privacy Manifest & Berechtigungstexte
- [ ] `ios/Runner/PrivacyInfo.xcprivacy` anlegen:
  - `NSPrivacyTracking` false, `NSPrivacyTrackingDomains` leer.
  - `NSPrivacyCollectedDataTypes`: EmailAddress, Name, UserID, PhotosorVideos, OtherUserContent. Jeweils Linked true, Tracking false, Purpose `NSPrivacyCollectedDataTypePurposeAppFunctionality`.
  - `NSPrivacyAccessedAPITypes`: UserDefaults mit Reason `CA92.1`.
- [ ] Datei per Ruby-`xcodeproj` zum Runner-Target hinzufügen (Resources Build Phase). Script im Scratchpad, ausgeführt mit `LANG=en_US.UTF-8`, Gem aus der CocoaPods-Installation. Danach `plutil -lint`.
- [ ] `Info.plist`: `NSPhotoLibraryUsageDescription` → „Booksquad benötigt Zugriff auf deine Fotos, um Profilbilder und Bilder für Beiträge auszuwählen.“ `NSCameraUsageDescription` entfernen, weil die App die Kamera nicht nutzt (`ImageSource.gallery` überall; vorher grep).
- [ ] `flutter build ios --simulator --debug` und prüfen, dass `PrivacyInfo.xcprivacy` im `.app` liegt.
- [ ] Commit, Push.

### Task 7: Fonts bündeln (DSGVO, offline)
- [ ] Source Serif 4 statisch (Regular 400, Medium 500, SemiBold 600, Bold 700) aus `github.com/google/fonts` (`ofl/sourceserif4/`) herunterladen.
  - Liegen dort nur Variable Fonts, die statischen TTFs aus dem offiziellen Adobe-Repo `adobe-fonts/source-serif` (Release, OFL) nehmen und im Report vermerken.
  - Die Dateien landen in `assets/google_fonts/` mit den von google_fonts erwarteten Namen (`SourceSerif4-Regular.ttf`, `-Medium`, `-SemiBold`, `-Bold`). `OFL.txt` kommt daneben.
- [ ] `pubspec.yaml` assets: `assets/google_fonts/`. In `main.dart` vor `runApp`: `GoogleFonts.config.allowRuntimeFetching = false;`.
- [ ] Test: Theme-Smoke-Test, der `AppTheme.light` baut und mit `allowRuntimeFetching = false` keinen Netzwerkzugriff versucht (google_fonts wirft sonst). Dazu Lizenzhinweis `LicenseRegistry.addLicense` für OFL.
- [ ] Simulator-Screenshot: Headlines in Serif.
- [ ] analyze + test, Commit, Push.

### Task 8: Rechtstexte & statische Seiten (nicht veröffentlicht)
- [ ] `docs/legal/PRIVACY.md` überarbeiten, Entwurf mit dem tatsächlichen Stand. Inhalt:
  - Verantwortlicher (Platzhalter)
  - Kategorien: Account, Inhalte, Bilder ohne Metadaten, technische Logs
  - Zwecke und Rechtsgrundlagen (Art. 6 (1) b, f DSGVO)
  - Empfänger: Supabase (Hosting EU/Frankfurt, AVV), Open Library/Internet Archive (Suchbegriffe, IP, USA), Apple und Google nur bei Social Login
  - Keine Werbung, kein Tracking. Fonts lokal.
  - Speicherdauer und Löschung (in-App sofort, inkl. Bilder)
  - Moderation (Meldungen, Auto-Ausblenden)
  - Betroffenenrechte, Beschwerderecht bei der Aufsichtsbehörde
  - Mindestalter 16, Änderungen, Stand
- [ ] `docs/legal/TERMS.md`:
  - Null-Toleranz für anstößige Inhalte und missbräuchliche Nutzer (Apple 1.2)
  - Melden, Blockieren, Moderation
  - Entfernung und Sperre ohne Vorankündigung bei Verstößen
  - Mindestalter 16
  - Nutzungsrechte an Inhalten (einfache Lizenz zur Anzeige), Haftung, Kündigung/Löschung, Kontakt
- [ ] `docs/legal/IMPRINT.md`: Platzhalter nach § 5 DDG.
- [ ] Neu `docs/legal/DELETE_ACCOUNT.md`: Konto löschen in der App plus Löschung per E-Mail-Anfrage. Was gelöscht wird, was nicht (anonyme Logs bis 30 Tage, falls zutreffend). Das ist die Play-Anforderung.
- [ ] Statische Seiten `site/index.html`, `privacy.html`, `terms.html`, `imprint.html`, `delete-account.html`, `site/style.css`. Schlichtes, responsives HTML im Booksquad-Look (Creme, Bordeaux, Serif), Inhalte 1:1 aus den MD-Dateien. Banner „Entwurf – nicht veröffentlicht“ nur in der MD-Version, nicht im HTML.
- [ ] `AppConfig`: URLs auf `https://getbooksquad.com/privacy.html` usw. plus neu `deleteAccountUrl`, mit Kommentar „live after GitHub Pages is enabled (see docs/RELEASE.md)“. `docs/RELEASE.md` bekommt den Abschnitt „Rechtstexte veröffentlichen“ (Pages aus `gh-pages`-Branch mit Inhalt von `site/`, oder eigene Domain).
- [ ] Commit, Push.

### Task 9: Store-Fragebögen
- [ ] `docs/STORE_PRIVACY.md`:
  - App Store Privacy „Nutrition Label“: Datentypen, verknüpft, kein Tracking
  - Google Play Data Safety: erhobene und geteilte Daten, Verschlüsselung in Transit, Löschanfrage-URL
  - Altersfreigabe-Hinweise (UGC → Apple 12+/17+-Abwägung, IARC: nutzergenerierte Inhalte und Interaktion)
  - App-Review-Notizen: Demo-Account-Platzhalter, Ablauf zum Melden und Blockieren, Moderationsprozess mit Reaktionszeit „innerhalb von 24 h“, Support-Kontakt
- [ ] Commit, Push.

### Task 10: Abschluss
- [ ] TESTING.md um Moderation ergänzen (Melden → Auto-Hide → Admin-Queue → Verwerfen/Löschen), außerdem Rate-Limit und Terms-Checkbox.
- [ ] Gesamt-Review über den Phase-2-Branch (Opus). Fixes.
- [ ] Simulator-Smoke (Login-Screen, Registrierung mit Checkbox).
- [ ] PR `phase-2/store-compliance` → `main`, Auto-Fix an.
