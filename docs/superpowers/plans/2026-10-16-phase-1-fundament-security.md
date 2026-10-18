# Phase 1 — Fundament & Security: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Booksquad baut wieder auf iOS und Android, CI ist grün, der Auth-State ist korrekt, und Datenbank und Storage sind so abgesichert, dass private Gruppen, Blockieren und Account-Löschung serverseitig wirklich funktionieren.

**Architecture:** Eine neue Supabase-Migration (`20261016120000_security_hardening.sql`) ersetzt die schwachen RLS-Policies. Sie nutzt `SECURITY DEFINER`-Hilfsfunktionen, damit Policies nicht rekursiv werden und Blocks sowie Mitgliedschaft unabhängig von der RLS der Hilfstabellen geprüft werden können. Account-Löschung läuft über eine Edge Function mit Service Role und Storage API. Im Client wird `currentUserProvider` reaktiv, der Router wird nur noch einmal gebaut, und die Redirect-Logik wandert in eine reine, testbare Funktion.

**Tech Stack:** Flutter 3.44.5 / Dart 3.12, Riverpod 2.6, go_router 16, supabase_flutter 2.16, Supabase (Postgres 17, Storage, Edge Functions/Deno), Paket `image` 4.x (neu).

---

## Phasen-Überblick (Kontext)

| Phase | Inhalt |
|---|---|
| **1 — Fundament & Security** (dieser Plan) | Builds, CI, Auth-Korrektheit, RLS/Storage, Signup-Trigger, Passwort-Reset + Deep Links, Account-Löschung, Einladungscodes, EXIF |
| 2 — Store-Compliance & Moderation | Report-Queue + Admin-Sicht, PrivacyInfo.xcprivacy, Legal-Seiten hosten, Play Data Safety, Google/Apple Sign-In echt konfigurieren + offizielle Buttons, Rate Limits |
| 3 — UI/UX-Politur | Umlaute, `flutter_localizations` + ARB, Accessibility, iOS-Back-Swipe, Kontraste, Empty/Error-States, Fonts bundeln, Create-Post als Modal |
| 4 — Performance & Features | Pagination, Count-Queries, optimistische Likes, Buch-Detailseite, Onboarding „Folge Lesern“ |
| 5 — Release | Prod-Supabase (Pro, Frankfurt), TestFlight + Play Internal Testing, Screenshots, Submit |

## Getroffene Entscheidungen

- **Private Gruppen:** Beitritt nur per Einladungscode (RPC `join_group_with_code`). Der Code ist für den Ersteller in der Gruppe sichtbar.
- **Supabase:** Das bestehende Projekt `thkfqvvzldkfxaqehjqn` („marcellomerico's Project“, aktuell **INACTIVE**) wird reaktiviert und dient als **Dev**. Prod kommt in Phase 5.
- **Freigaben:** Jede Aktion gegen Supabase (Restore, Migration, Edge-Function-Deploy, SQL-Tests) und jeder Commit braucht vorher ein OK von Marcello.
- **Keine Test-Accounts durch Claude:** Die manuellen App-Tests mit Login führt Marcello selbst durch.

## Datei-Übersicht

| Datei | Aktion | Zweck |
|---|---|---|
| `ios/Podfile`, `ios/Runner.xcodeproj/project.pbxproj` | Modify | iOS 15.0 Deployment Target |
| `.github/workflows/flutter.yml` | Modify | `.env` aus Example, Flutter-Version pinnen |
| `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml` | Modify | Kein Debug-Signing-Fallback, Label, Backup aus, Deep Link |
| `ios/Runner/Info.plist` | Modify | URL-Scheme `booksquad`, Flutter-Deeplinking aus |
| `lib/features/auth/providers/auth_provider.dart` | Modify | Reaktiver `currentUserProvider`, `passwordRecoveryProvider`, Signup ohne Upsert, Edge-Function-Löschung, `updatePassword`, saubere Fehlermeldungen |
| `lib/core/router/auth_redirect.dart` | Create | Reine Redirect-Funktion |
| `lib/core/router/splash_screen.dart` | Create | Lade-Route statt Login-Flash |
| `lib/core/router/app_router.dart` | Modify | Router einmalig bauen, neue Routen |
| `lib/features/auth/presentation/reset_password_screen.dart` | Create | Neues Passwort setzen |
| `lib/core/constants/app_config.dart` | Modify | `authRedirectUrl`, `AppLimits` |
| `lib/core/utils/validators.dart` | Create | `validateUsername`, `sanitizeSearchTerm` |
| `lib/core/utils/image_sanitizer.dart` | Create | EXIF entfernen, Größe begrenzen |
| `lib/features/auth/presentation/register_screen.dart` | Modify | Username-Validierung |
| `lib/repositories/profile_repository.dart` | Modify | `username_available`-RPC, Suche escapen |
| `lib/repositories/group_repository.dart`, `lib/models/group.dart` | Modify | Invite-Code, insert statt upsert |
| `lib/features/groups/presentation/group_detail_screen.dart`, `groups_screen.dart` | Modify | Code anzeigen / mit Code beitreten |
| `lib/repositories/post_repository.dart`, `follow_repository.dart` | Modify | `ignoreDuplicates`, Bild beim Löschen entfernen |
| `lib/features/feed/presentation/create_post_screen.dart`, `post_detail_screen.dart`, `lib/features/profile/presentation/edit_profile_screen.dart`, `lib/features/auth/presentation/onboarding_screen.dart`, `lib/core/widgets/moderation_actions.dart` | Modify | `maxLength`, Bild-Sanitizing |
| `supabase/migrations/20261016120000_security_hardening.sql` | Create | RLS, Helper, Invite, Trigger, Constraints, Storage |
| `supabase/tests/rls_smoke.sql` | Create | RLS-Regressionstest (Transaktion + Rollback) |
| `supabase/functions/delete-account/index.ts` | Create | Account + Dateien löschen |
| `test/helpers/auth_fixtures.dart` + diverse `test/**` | Create | Tests |
| `supabase/APPLY_MIGRATIONS.md`, `README.md` | Modify | Doku |

---

### Task 0: Vorbereitung (mit Marcello)

**Files:** keine

- [ ] **Step 1: Bestehende uncommitted Arbeit sichern.** Auf `cursor/phase-1-flutter-foundation` liegen ~60 geänderte bzw. neue Dateien uncommitted. **Marcello fragen**, ob sie als Snapshot committet werden dürfen:

```bash
git add -A && git commit -m "chore: snapshot client work before phase 1"
```

Danach ist `docs/REVIEW_2026-10.md` mit drin. Prüfen, dass `.env` **nicht** im Commit ist (`git show --stat HEAD | grep -c '\.env$'` muss `0` ergeben).

- [ ] **Step 2: Arbeitsbranch anlegen**

```bash
git switch -c phase-1/foundation-security
```

- [ ] **Step 3: Supabase-Dev-Projekt reaktivieren (nach OK).** Über das Supabase-MCP `restore_project` mit `project_id: thkfqvvzldkfxaqehjqn` oder im Dashboard per „Restore project“. Anschließend mit `list_migrations` und `list_tables` prüfen, welche der 4 bisherigen Migrationen angewendet sind. Fehlende Migrationen 1–4 in Reihenfolge nachziehen (nach OK).

---

### Task 1: iOS-Build reparieren (Deployment Target 15.0)

**Files:**
- Modify: `ios/Podfile:1-2, 39-43`
- Modify: `ios/Runner.xcodeproj/project.pbxproj` (3× `IPHONEOS_DEPLOYMENT_TARGET = 13.0;`, Zeilen ~474, ~605, ~656)

- [ ] **Step 1: Fehler reproduzieren**

Run: `cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator build 2>&1 | grep -m1 "deployment target"`
Expected: `error: The iOS Simulator deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 13.0, but the range of supported deployment target versions is 15.0 to 27.1.x.`

- [ ] **Step 2: Podfile anpassen.** Zeilen 1–2 ersetzen durch:

```ruby
platform :ios, '15.0'
```

`post_install` (Zeilen 39–43) ersetzen durch:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    # Xcode 27 rejects pod targets below iOS 15.
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

- [ ] **Step 3: Xcode-Projekt anpassen**

```bash
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' ios/Runner.xcodeproj/project.pbxproj
grep -c 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' ios/Runner.xcodeproj/project.pbxproj
```

Expected: `3`

- [ ] **Step 4: Pods neu installieren.** Die UTF-8-Locale ist nötig, sonst crasht CocoaPods unter Ruby 4 mit `Encoding::CompatibilityError`.

```bash
cd ios && LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install && cd ..
```

Expected: `Pod installation complete!`

- [ ] **Step 5: Bauen**

Run: `cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator build 2>&1 | grep -E '\*\* BUILD'; cd ..`
Expected: `** BUILD SUCCEEDED **`

Danach `flutter build ios --simulator --debug` ausführen. Im Review lief `xcodebuild` grün, während `flutter build` noch mit `Exited with status code 255` endete. Falls das bestehen bleibt: `flutter clean && flutter pub get` und erneut versuchen. Hilft das nicht, den Fehler mit `flutter build ios --simulator --debug -v 2>&1 | grep -iE "error|255" | tail -20` eingrenzen und als eigenen Fix-Step dokumentieren.

- [ ] **Step 6: Commit (nach OK)**

```bash
git add ios/Podfile ios/Podfile.lock ios/Runner.xcodeproj/project.pbxproj
git commit -m "fix(ios): raise deployment target to iOS 15 for Xcode 27"
```

---

### Task 2: CI reparieren

**Files:**
- Modify: `.github/workflows/flutter.yml`

- [ ] **Step 1: Fehler reproduzieren (frischer Clone)**

```bash
rm -rf /tmp/bm-ci && git clone -q . /tmp/bm-ci && cd /tmp/bm-ci && flutter pub get >/dev/null && flutter analyze | tail -2; cd -
```

Expected: `warning • The asset file '.env' doesn't exist` und `1 issue found.`

- [ ] **Step 2: Workflow ersetzen** (komplette Datei):

```yaml
name: Flutter CI

on:
  push:
    branches: [main, master, 'cursor/**', 'phase-*/**']
  pull_request:

jobs:
  analyze-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.5
      # .env is a bundled asset but gitignored; placeholder values keep Env.isConfigured false.
      - run: cp .env.example .env
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

- [ ] **Step 3: Verifizieren**

```bash
cp .github/workflows/flutter.yml /tmp/bm-ci/.github/workflows/ && cd /tmp/bm-ci && cp .env.example .env && flutter analyze | tail -1 && flutter test | tail -1; cd -
```

Expected: `No issues found!` und `All tests passed!`

- [ ] **Step 4: Commit (nach OK)**

```bash
git add .github/workflows/flutter.yml
git commit -m "ci: provide .env placeholder and pin Flutter 3.44.5"
```

---

### Task 3: Android-Release-Konfiguration

**Files:**
- Modify: `android/app/build.gradle.kts:44-52`
- Modify: `android/app/src/main/AndroidManifest.xml:3-6`

- [ ] **Step 1: Signing ohne Debug-Fallback.** `buildTypes` ersetzen durch:

```kotlin
    buildTypes {
        release {
            // No debug fallback: an unsigned release build fails loudly instead of shipping a debug key.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
```

- [ ] **Step 2: Manifest anpassen.** Das `<application …>`-Tag ersetzen durch:

```xml
    <application
        android:label="Booksquad"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="false"
        android:fullBackupContent="false">
```

- [ ] **Step 3: Verifizieren**

Run: `flutter build apk --debug 2>&1 | tail -1`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 4: Commit (nach OK)**

```bash
git add android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml
git commit -m "fix(android): no debug-key fallback for release, disable backup, proper label"
```

---

### Task 4: `currentUserProvider` reaktiv machen

**Files:**
- Create: `test/helpers/auth_fixtures.dart`
- Create: `test/features/auth/current_user_provider_test.dart`
- Modify: `lib/features/auth/providers/auth_provider.dart:22-24`

- [ ] **Step 1: Test-Fixtures anlegen** (`test/helpers/auth_fixtures.dart`):

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

User testUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

Session testSession(String userId) => Session(
      accessToken: 'test-access-token',
      tokenType: 'bearer',
      user: testUser(userId),
    );

AuthState signedIn(String userId) =>
    AuthState(AuthChangeEvent.signedIn, testSession(userId));

AuthState signedOut() => AuthState(AuthChangeEvent.signedOut, null);

SupabaseClient offlineClient() => SupabaseClient(
      'http://localhost:54321',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
```

- [ ] **Step 2: Failing Test schreiben** (`test/features/auth/current_user_provider_test.dart`):

```dart
import 'dart:async';

import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_fixtures.dart';

void main() {
  test('currentUserProvider follows sign-in, sign-out and account switch', () async {
    final controller = StreamController<AuthState>();
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(offlineClient()),
        authStateProvider.overrideWith((ref) => controller.stream),
      ],
    );
    addTearDown(() {
      container.dispose();
      controller.close();
    });
    container.listen(currentUserProvider, (_, _) {});

    expect(container.read(currentUserProvider), isNull);

    controller.add(signedIn('user-a'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentUserProvider)?.id, 'user-a');

    controller.add(signedOut());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentUserProvider), isNull);

    controller.add(signedIn('user-b'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentUserProvider)?.id, 'user-b');
  });
}
```

- [ ] **Step 3: Test laufen lassen, muss fehlschlagen**

Run: `flutter test test/features/auth/current_user_provider_test.dart`
Expected: FAIL. `Expected: 'user-a' Actual: <null>`

- [ ] **Step 4: Implementieren.** In `auth_provider.dart` den `currentUserProvider` ersetzen durch:

```dart
final currentUserProvider = Provider<User?>((ref) {
  // Recompute only when the signed-in user changes, not on every token refresh.
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.session?.user.id));
  final auth = ref.read(authStateProvider);
  if (auth.hasValue) return auth.value!.session?.user;
  // Before the first auth event: fall back to the persisted session.
  return ref.watch(supabaseClientProvider).auth.currentUser;
});
```

- [ ] **Step 5: Test grün**

Run: `flutter test test/features/auth/current_user_provider_test.dart`
Expected: PASS

- [ ] **Step 6: Commit (nach OK)**

```bash
git add test/helpers/auth_fixtures.dart test/features/auth/current_user_provider_test.dart lib/features/auth/providers/auth_provider.dart
git commit -m "fix(auth): make currentUserProvider react to sign-in, sign-out and account switch"
```

---

### Task 5: `passwordRecoveryProvider`

**Files:**
- Create: `test/features/auth/password_recovery_provider_test.dart`
- Modify: `lib/features/auth/providers/auth_provider.dart` (direkt nach `currentUserProvider`)

- [ ] **Step 1: Failing Test**

```dart
import 'dart:async';

import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_fixtures.dart';

void main() {
  test('flag is set by passwordRecovery event and cleared by done()', () async {
    final controller = StreamController<AuthState>();
    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith((ref) => controller.stream)],
    );
    addTearDown(() {
      container.dispose();
      controller.close();
    });
    container.listen(passwordRecoveryProvider, (_, _) {});

    expect(container.read(passwordRecoveryProvider), isFalse);

    controller.add(AuthState(AuthChangeEvent.passwordRecovery, testSession('u1')));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(passwordRecoveryProvider), isTrue);

    container.read(passwordRecoveryProvider.notifier).done();
    expect(container.read(passwordRecoveryProvider), isFalse);
  });

  test('sign-out clears the flag', () async {
    final controller = StreamController<AuthState>();
    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith((ref) => controller.stream)],
    );
    addTearDown(() {
      container.dispose();
      controller.close();
    });
    container.listen(passwordRecoveryProvider, (_, _) {});

    controller.add(AuthState(AuthChangeEvent.passwordRecovery, testSession('u1')));
    await Future<void>.delayed(Duration.zero);
    controller.add(signedOut());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(passwordRecoveryProvider), isFalse);
  });
}
```

- [ ] **Step 2: Fehlschlag prüfen**

Run: `flutter test test/features/auth/password_recovery_provider_test.dart`
Expected: FAIL mit Compile-Fehler `Undefined name 'passwordRecoveryProvider'`

- [ ] **Step 3: Implementieren** (in `auth_provider.dart` nach `currentUserProvider`):

```dart
/// True after the user opened a password-reset link until a new password is set.
class PasswordRecovery extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authStateProvider, (_, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery) state = true;
      if (event == AuthChangeEvent.signedOut) state = false;
    });
    return false;
  }

  void done() => state = false;
}

final passwordRecoveryProvider =
    NotifierProvider<PasswordRecovery, bool>(PasswordRecovery.new);
```

- [ ] **Step 4: Test grün**

Run: `flutter test test/features/auth/password_recovery_provider_test.dart`
Expected: PASS (2 Tests)

- [ ] **Step 5: Commit (nach OK)**

```bash
git add test/features/auth/password_recovery_provider_test.dart lib/features/auth/providers/auth_provider.dart
git commit -m "feat(auth): track password recovery state"
```

---

### Task 6: Redirect als reine Funktion

**Files:**
- Create: `lib/core/router/auth_redirect.dart`
- Create: `test/core/router/auth_redirect_test.dart`

- [ ] **Step 1: Failing Test**

```dart
import 'package:booksquad/core/router/auth_redirect.dart';
import 'package:booksquad/models/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_fixtures.dart';

const _done = Profile(id: 'u1', username: 'u1', onboardingCompleted: true);
const _fresh = Profile(id: 'u1', username: 'u1');

String? _go(
  String location, {
  required AsyncValue<AuthState> auth,
  AsyncValue<Profile?> profile = const AsyncData(null),
  bool recovering = false,
}) =>
    authRedirect(
      location: location,
      auth: auth,
      profile: profile,
      recoveringPassword: recovering,
    );

void main() {
  final signedInU1 = AsyncData<AuthState>(signedIn('u1'));
  final signedOutState = AsyncData<AuthState>(signedOut());
  const authLoading = AsyncLoading<AuthState>();

  group('auth loading', () {
    test('goes to splash', () => expect(_go('/home', auth: authLoading), '/splash'));
    test('stays on splash', () => expect(_go('/splash', auth: authLoading), isNull));
  });

  group('signed out', () {
    test('protected route -> login', () => expect(_go('/home', auth: signedOutState), '/login'));
    test('splash -> login', () => expect(_go('/splash', auth: signedOutState), '/login'));
    for (final route in ['/login', '/register', '/forgot-password']) {
      test('$route is reachable', () => expect(_go(route, auth: signedOutState), isNull));
    }
  });

  group('signed in', () {
    test('profile loading without value -> splash', () {
      expect(_go('/home', auth: signedInU1, profile: const AsyncLoading()), '/splash');
    });
    test('stale profile of previous user while loading -> splash', () {
      const other = Profile(id: 'old', username: 'old', onboardingCompleted: true);
      final stale = const AsyncLoading<Profile?>().copyWithPrevious(const AsyncData(other));
      expect(_go('/home', auth: signedInU1, profile: stale), '/splash');
    });
    test('refreshing own profile does not flash splash', () {
      final refreshing = const AsyncLoading<Profile?>().copyWithPrevious(const AsyncData(_done));
      expect(_go('/posts/1', auth: signedInU1, profile: refreshing), isNull);
    });
    test('onboarding incomplete -> onboarding', () {
      expect(_go('/home', auth: signedInU1, profile: const AsyncData(_fresh)), '/onboarding');
    });
    test('missing profile row -> onboarding', () {
      expect(_go('/home', auth: signedInU1, profile: const AsyncData(null)), '/onboarding');
    });
    test('book search allowed during onboarding', () {
      expect(_go('/books/search', auth: signedInU1, profile: const AsyncData(_fresh)), isNull);
    });
    for (final route in ['/login', '/register', '/splash', '/onboarding', '/forgot-password', '/reset-password']) {
      test('$route -> home when onboarded', () {
        expect(_go(route, auth: signedInU1, profile: const AsyncData(_done)), '/home');
      });
    }
    test('deep route stays', () {
      expect(_go('/posts/1', auth: signedInU1, profile: const AsyncData(_done)), isNull);
    });
  });

  group('password recovery', () {
    test('forces reset screen', () {
      expect(_go('/home', auth: signedInU1, profile: const AsyncData(_done), recovering: true), '/reset-password');
    });
    test('reset screen stays', () {
      expect(_go('/reset-password', auth: signedInU1, profile: const AsyncData(_done), recovering: true), isNull);
    });
  });
}
```

- [ ] **Step 2: Fehlschlag prüfen**

Run: `flutter test test/core/router/auth_redirect_test.dart`
Expected: FAIL: `Target of URI doesn't exist: 'package:booksquad/core/router/auth_redirect.dart'`

- [ ] **Step 3: Implementieren** (`lib/core/router/auth_redirect.dart`):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';

const _publicRoutes = {'/login', '/register', '/forgot-password'};
const _onboardingRoutes = {'/onboarding', '/books/search'};
const _entryRoutes = {
  ..._publicRoutes,
  '/splash',
  '/onboarding',
  '/reset-password',
};

String? _stayOr(String location, String target) =>
    location == target ? null : target;

/// Pure routing decision; kept free of Riverpod refs so it can be unit tested.
String? authRedirect({
  required String location,
  required AsyncValue<AuthState> auth,
  required AsyncValue<Profile?> profile,
  required bool recoveringPassword,
}) {
  if (!auth.hasValue) {
    return auth.hasError ? _stayOr(location, '/login') : _stayOr(location, '/splash');
  }

  final userId = auth.value!.session?.user.id;
  if (userId == null) {
    return _publicRoutes.contains(location) ? null : '/login';
  }

  if (recoveringPassword) return _stayOr(location, '/reset-password');

  final current = profile.valueOrNull;
  final hasOwnProfile = current != null && current.id == userId;
  if (profile.isLoading && !hasOwnProfile) return _stayOr(location, '/splash');

  final onboarded = hasOwnProfile && current.onboardingCompleted;
  if (!onboarded) {
    return _onboardingRoutes.contains(location) ? null : '/onboarding';
  }

  return _entryRoutes.contains(location) ? '/home' : null;
}
```

- [ ] **Step 4: Tests grün**

Run: `flutter test test/core/router/auth_redirect_test.dart`
Expected: PASS (alle)

- [ ] **Step 5: Commit (nach OK)**

```bash
git add lib/core/router/auth_redirect.dart test/core/router/auth_redirect_test.dart
git commit -m "feat(router): extract auth redirect into a pure, tested function"
```

---

### Task 7: Router nur einmal bauen, Splash, Forgot-Password erreichbar

**Files:**
- Create: `lib/core/router/splash_screen.dart`
- Modify: `lib/core/router/app_router.dart:21-63` (Provider-Kopf + `redirect`) und `:165-174` (`_RouterRefresh`)

- [ ] **Step 1: Splash anlegen** (`lib/core/router/splash_screen.dart`):

```dart
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
```

- [ ] **Step 2: Router-Provider ersetzen.** Alles von `final routerProvider = Provider<GoRouter>((ref) {` bis einschließlich zum Ende des `redirect:`-Callbacks (vor `routes: [`) ersetzen durch:

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    // Read (not watch) so auth/profile changes re-run redirect instead of rebuilding the router.
    redirect: (context, state) => authRedirect(
      location: state.matchedLocation,
      auth: ref.read(authStateProvider),
      profile: ref.read(currentProfileProvider),
      recoveringPassword: ref.read(passwordRecoveryProvider),
    ),
```

Am Ende des Providers, statt `  );\n});`:

```dart
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
```

- [ ] **Step 3: Neue Routen** an den Anfang der `routes:`-Liste:

```dart
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const ResetPasswordScreen()),
      ),
```

Imports ergänzen:

```dart
import '../../features/auth/presentation/reset_password_screen.dart';
import 'auth_redirect.dart';
import 'splash_screen.dart';
```

(`ResetPasswordScreen` kommt in Task 8. Bis dahin kompiliert die Datei nicht, deshalb Task 7 und Task 8 zusammen committen.)

- [ ] **Step 4: `_RouterRefresh` ersetzen durch:**

```dart
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
    ref.listen(passwordRecoveryProvider, (_, _) => notifyListeners());
  }
}
```

- [ ] **Step 5:** weiter mit Task 8, danach gemeinsamer Test und Commit.

---

### Task 8: Passwort-Reset Ende-zu-Ende (Deep Link + Screen)

**Files:**
- Modify: `lib/core/constants/app_config.dart`
- Modify: `lib/features/auth/providers/auth_provider.dart` (`resetPassword`, neues `updatePassword`, `signUp`)
- Create: `lib/features/auth/presentation/reset_password_screen.dart`
- Modify: `ios/Runner/Info.plist` (`CFBundleURLTypes`, neuer Key)
- Modify: `android/app/src/main/AndroidManifest.xml` (Intent-Filter + Meta-Data in `<activity>`)

- [ ] **Step 1: Redirect-URL zentral.** In `AppConfig` nach `imprintUrl` einfügen:

```dart
  /// Deep link Supabase redirects to after e-mail confirmation / password reset.
  /// Must also be listed under Auth → URL Configuration → Redirect URLs.
  static const authRedirectUrl = 'booksquad://auth-callback';
```

- [ ] **Step 2: Repository.** In `AuthRepository` `resetPassword` ersetzen und `updatePassword` hinzufügen:

```dart
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.authRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }
```

Im `signUp`-Aufruf `emailRedirectTo: AppConfig.authRedirectUrl,` ergänzen. Import: `import '../../../core/constants/app_config.dart';`

- [ ] **Step 3: Screen** (`lib/features/auth/presentation/reset_password_screen.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/booksquad_ui.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = 'Mindestens 8 Zeichen.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Die Passwörter stimmen nicht überein.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(password);
      // Clearing the flag lets the router redirect to /home.
      ref.read(passwordRecoveryProvider.notifier).done();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neues Passwort')),
      body: SafeArea(
        child: KeyboardSafeScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Neues Passwort festlegen', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(hintText: 'Neues Passwort'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(hintText: 'Passwort wiederholen'),
                onSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

(Falls `KeyboardSafeScroll` in `booksquad_ui.dart` eine andere Signatur hat, an `forgot_password_screen.dart` orientieren. Dort wird es identisch verwendet.)

- [ ] **Step 4: iOS URL-Scheme.** In `Info.plist` im `CFBundleURLTypes`-Array einen zweiten `<dict>` ergänzen und vor `</dict></plist>` den Deeplinking-Key setzen:

```xml
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>booksquad</string>
			</array>
		</dict>
```

```xml
	<!-- supabase_flutter handles auth deep links; keep go_router from routing them. -->
	<key>FlutterDeepLinkingEnabled</key>
	<false/>
```

- [ ] **Step 5: Android Intent-Filter.** In `<activity …>` nach dem bestehenden `<intent-filter>` einfügen:

```xml
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="booksquad" android:host="auth-callback"/>
            </intent-filter>
            <meta-data android:name="flutter_deeplinking_enabled" android:value="false"/>
```

- [ ] **Step 6: Analyze + alle Tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` und `All tests passed!`

- [ ] **Step 7: Supabase-Dashboard (Marcello, manuell).** Unter Auth → URL Configuration bei Redirect URLs `booksquad://auth-callback` hinzufügen.

- [ ] **Step 8: Manueller Test (Marcello, Simulator/Gerät)**

1. App startet ohne Login-Flash auf dem Splash-Screen und geht dann zu Login oder Home.
2. Login → „Passwort vergessen?“ öffnet den Screen (vorher: nichts passiert).
3. Reset-Mail anfordern → Link auf dem Gerät öffnen → die App zeigt „Neues Passwort“ → speichern → Home.
4. Profil bearbeiten und speichern → der Navigations-Stack bleibt erhalten (kein Sprung zurück).
5. Ausloggen, mit anderem Account einloggen → Profil, Regal und Feed zeigen den neuen User.

- [ ] **Step 9: Commit (nach OK)**

```bash
git add lib/core/router/ lib/features/auth/ lib/core/constants/app_config.dart ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "fix(auth): build router once, add splash and working password reset via deep link"
```

---

### Task 9: Signup reparieren und Username validieren

**Files:**
- Create: `lib/core/utils/validators.dart`
- Create: `test/core/utils/validators_test.dart`
- Modify: `lib/features/auth/providers/auth_provider.dart` (`signUp`, `authErrorMessage`)
- Modify: `lib/repositories/profile_repository.dart:57-67` (`isUsernameAvailable`)
- Modify: `lib/features/auth/presentation/register_screen.dart:35-56`

- [ ] **Step 1: Failing Test** (`test/core/utils/validators_test.dart`):

```dart
import 'package:booksquad/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateUsername', () {
    for (final ok in ['max', 'lese_ratte', 'anna.k', 'a1b2c3', 'x' * 24]) {
      test('accepts $ok', () => expect(validateUsername(ok), isNull));
    }
    for (final bad in ['', 'ab', 'Max', 'max mustermann', 'müller', 'max-m', 'x' * 25]) {
      test('rejects "$bad"', () => expect(validateUsername(bad), isNotNull));
    }
  });

  group('sanitizeSearchTerm', () {
    test('strips PostgREST/LIKE control characters', () {
      expect(sanitizeSearchTerm('a,b(c)%d*e\\f"g'), 'a b c  d e f g');
    });
    test('keeps dots and underscores used in usernames', () {
      expect(sanitizeSearchTerm(' anna.k_1 '), 'anna.k_1');
    });
  });
}
```

- [ ] **Step 2: Fehlschlag prüfen**

Run: `flutter test test/core/utils/validators_test.dart`
Expected: FAIL: `Target of URI doesn't exist`

- [ ] **Step 3: Implementieren** (`lib/core/utils/validators.dart`):

```dart
final _usernamePattern = RegExp(r'^[a-z0-9_.]{3,24}$');

/// Mirrors the DB check `profiles_username_format` (DB allows 30 to leave room for suffixes).
String? validateUsername(String value) {
  if (_usernamePattern.hasMatch(value)) return null;
  return 'Benutzername: 3–24 Zeichen, nur a–z, 0–9, _ und .';
}

/// Removes characters with meaning inside PostgREST `or()` filters or LIKE patterns.
String sanitizeSearchTerm(String input) =>
    input.replaceAll(RegExp(r'[,()%*\\"]'), ' ').trim();
```

- [ ] **Step 4: Test grün**

Run: `flutter test test/core/utils/validators_test.dart`
Expected: PASS

- [ ] **Step 5: Register-Screen.** In `_signUp()` die erste Zeile und den Username-Check ersetzen:

```dart
    final username = _usernameController.text.trim().toLowerCase();
```

und direkt nach dem `isEmpty`-Check:

```dart
    final usernameError = validateUsername(username);
    if (usernameError != null) {
      setState(() => _error = usernameError);
      return;
    }
```

Import: `import '../../../core/utils/validators.dart';`

- [ ] **Step 6: Username-Verfügbarkeit über RPC.** Profile werden nach der Migration nur noch für eingeloggte User lesbar sein. `isUsernameAvailable` ersetzen durch:

```dart
  Future<bool> isUsernameAvailable(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return false;
    final result = await _client.rpc(
      'username_available',
      params: {'p_username': trimmed},
    );
    return result == true;
  }
```

- [ ] **Step 7: Suche escapen.** In `searchProfiles` `final trimmed = query.trim();` ersetzen durch:

```dart
    final trimmed = sanitizeSearchTerm(query);
```

Import: `import '../core/utils/validators.dart';`

- [ ] **Step 8: `signUp` ohne Profil-Upsert.** Der Trigger legt das Profil aus den Metadaten an. Den gesamten Block ab `// Trigger may have created a profile` bis einschließlich `rethrow;\n    }` löschen.

- [ ] **Step 9: Entwickler-Hinweise aus Fehlermeldungen entfernen.** In `authErrorMessage`:

```dart
    if (message.contains('user already registered')) {
      return 'Diese E-Mail ist bereits registriert.';
    }
```

```dart
    if (message.contains('could not be deleted') ||
        message.contains('account could not')) {
      return 'Konto konnte nicht gelöscht werden. Bitte später erneut versuchen.';
    }
```

Die beiden Fallbacks `return error.message;` (AuthException und PostgrestException) ersetzen durch:

```dart
    debugPrint('Auth error: ${error.message}');
    return 'Ein Fehler ist aufgetreten. Bitte erneut versuchen.';
```

- [ ] **Step 10: Analyze + Tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` und `All tests passed!`

- [ ] **Step 11: Commit (nach OK)**

```bash
git add lib/core/utils/validators.dart test/core/utils/validators_test.dart lib/features/auth/ lib/repositories/profile_repository.dart
git commit -m "fix(auth): validate usernames, check availability via RPC, drop broken profile upsert"
```

---

### Task 10: Security-Migration schreiben

**Files:**
- Create: `supabase/migrations/20261016120000_security_hardening.sql`

- [ ] **Step 1: Migration anlegen** (komplette Datei):

```sql
-- Phase 1 security hardening.
-- Requires migrations 20260707180000 … 20260731150000.
-- Fixes: private-group self-join, leaking comments/likes, posting into foreign groups,
-- client-only blocking, anon scraping, unbounded input, username collisions, storage abuse.

-- =====================================================================
-- Helpers. SECURITY DEFINER so policies can check membership/blocks
-- without recursing into (or being hidden by) the RLS of those tables.
-- =====================================================================
create or replace function public.is_group_member(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

create or replace function public.can_view_group(gid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.groups g
    where g.id = gid
      and (g.is_private = false or g.creator_id = auth.uid() or public.is_group_member(gid))
  );
$$;

create or replace function public.is_blocked_with(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = auth.uid() and blocked_id = other)
       or (blocker_id = other and blocked_id = auth.uid())
  );
$$;

create or replace function public.can_view_post(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.posts p
    where p.id = pid
      and (p.group_id is null or public.can_view_group(p.group_id))
      and not public.is_blocked_with(p.author_id)
  );
$$;

revoke all on function public.is_group_member(uuid) from public, anon;
revoke all on function public.can_view_group(uuid) from public, anon;
revoke all on function public.is_blocked_with(uuid) from public, anon;
revoke all on function public.can_view_post(uuid) from public, anon;
grant execute on function public.is_group_member(uuid) to authenticated;
grant execute on function public.can_view_group(uuid) to authenticated;
grant execute on function public.is_blocked_with(uuid) to authenticated;
grant execute on function public.can_view_post(uuid) to authenticated;

-- =====================================================================
-- Groups + invite codes
-- =====================================================================
alter table public.groups
  add column if not exists invite_code text unique
  default substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);

drop policy if exists "Groups visible to members or public" on public.groups;
create policy "Groups visible to members or public" on public.groups
  for select to authenticated
  using (is_private = false or creator_id = auth.uid() or public.is_group_member(id));

drop policy if exists "Users can create groups" on public.groups;
create policy "Users can create groups" on public.groups
  for insert to authenticated
  with check (creator_id = auth.uid());

drop policy if exists "Creators update own groups" on public.groups;
create policy "Creators update own groups" on public.groups
  for update to authenticated
  using (creator_id = auth.uid())
  with check (creator_id = auth.uid());

-- =====================================================================
-- Group members: no more self-insert into private groups / self-promotion
-- =====================================================================
drop policy if exists "Group members are public" on public.group_members;
drop policy if exists "Users manage own membership" on public.group_members;

create policy "Members visible with group" on public.group_members
  for select to authenticated
  using (public.can_view_group(group_id));

create policy "Join public groups, creator joins own group as admin" on public.group_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      (role = 'member' and exists (
        select 1 from public.groups g where g.id = group_id and g.is_private = false))
      or (role = 'admin' and exists (
        select 1 from public.groups g where g.id = group_id and g.creator_id = auth.uid()))
    )
  );

create policy "Leave group or creator removes member" on public.group_members
  for delete to authenticated
  using (
    user_id = auth.uid()
    or exists (select 1 from public.groups g where g.id = group_id and g.creator_id = auth.uid())
  );

create or replace function public.join_group_with_code(code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  gid uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  select id into gid from public.groups where invite_code = lower(trim(code));
  if gid is null then
    raise exception 'Invalid invite code' using errcode = 'P0002';
  end if;
  insert into public.group_members (group_id, user_id, role)
  values (gid, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;
  return gid;
end;
$$;

revoke all on function public.join_group_with_code(text) from public, anon;
grant execute on function public.join_group_with_code(text) to authenticated;

-- =====================================================================
-- Posts
-- =====================================================================
drop policy if exists "Posts visible by visibility rules" on public.posts;
create policy "Posts visible by visibility rules" on public.posts
  for select to authenticated
  using (
    (group_id is null or public.can_view_group(group_id))
    and not public.is_blocked_with(author_id)
  );

drop policy if exists "Users create own posts" on public.posts;
create policy "Users create own posts" on public.posts
  for insert to authenticated
  with check (author_id = auth.uid() and (group_id is null or public.is_group_member(group_id)));

drop policy if exists "Users update own posts" on public.posts;
create policy "Users update own posts" on public.posts
  for update to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid() and (group_id is null or public.is_group_member(group_id)));

-- =====================================================================
-- Comments
-- =====================================================================
drop policy if exists "Comments are public" on public.comments;
create policy "Comments visible with post" on public.comments
  for select to authenticated
  using (public.can_view_post(post_id) and not public.is_blocked_with(author_id));

drop policy if exists "Users create own comments" on public.comments;
create policy "Users create own comments" on public.comments
  for insert to authenticated
  with check (author_id = auth.uid() and public.can_view_post(post_id));

-- =====================================================================
-- Likes (client must use upsert with ignoreDuplicates — no UPDATE policy)
-- =====================================================================
drop policy if exists "Likes are public" on public.likes;
drop policy if exists "Users manage own likes" on public.likes;
create policy "Likes visible with post" on public.likes
  for select to authenticated using (public.can_view_post(post_id));
create policy "Users like visible posts" on public.likes
  for insert to authenticated
  with check (user_id = auth.uid() and public.can_view_post(post_id));
create policy "Users remove own likes" on public.likes
  for delete to authenticated using (user_id = auth.uid());

-- =====================================================================
-- Follows + blocking side effects
-- =====================================================================
drop policy if exists "Follows are public" on public.follows;
drop policy if exists "Users manage own follows" on public.follows;
create policy "Follows visible to signed-in users" on public.follows
  for select to authenticated using (true);
create policy "Users follow unblocked users" on public.follows
  for insert to authenticated
  with check (follower_id = auth.uid() and not public.is_blocked_with(following_id));
create policy "Users unfollow" on public.follows
  for delete to authenticated using (follower_id = auth.uid());

create or replace function public.remove_follows_on_block()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.follows
  where (follower_id = new.blocker_id and following_id = new.blocked_id)
     or (follower_id = new.blocked_id and following_id = new.blocker_id);
  return new;
end;
$$;

drop trigger if exists on_block_remove_follows on public.blocks;
create trigger on_block_remove_follows
  after insert on public.blocks
  for each row execute function public.remove_follows_on_block();

-- =====================================================================
-- No anonymous scraping of the social graph
-- =====================================================================
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
create policy "Profiles visible to signed-in users" on public.profiles
  for select to authenticated using (true);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "User genres are public" on public.user_genres;
create policy "User genres visible to signed-in users" on public.user_genres
  for select to authenticated using (true);

drop policy if exists "User books are public" on public.user_books;
create policy "User books visible to signed-in users" on public.user_books
  for select to authenticated using (true);

drop policy if exists "Books are public" on public.books;
create policy "Books visible to signed-in users" on public.books
  for select to authenticated using (true);

-- =====================================================================
-- Usernames: normalise legacy rows, then enforce format + case-insensitive uniqueness
-- =====================================================================
update public.profiles
set username = left(regexp_replace(lower(username), '[^a-z0-9_.]', '', 'g'), 21)
               || '_' || substr(replace(id::text, '-', ''), 1, 6)
where username !~ '^[a-z0-9_.]{3,30}$';

alter table public.profiles
  add constraint profiles_username_format check (username ~ '^[a-z0-9_.]{3,30}$');
create unique index if not exists profiles_username_lower_key on public.profiles (lower(username));

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  base text;
  candidate text;
  n int := 0;
begin
  base := lower(coalesce(
    nullif(new.raw_user_meta_data->>'username', ''),
    split_part(coalesce(new.email, ''), '@', 1)
  ));
  base := left(regexp_replace(base, '[^a-z0-9_.]', '', 'g'), 24);
  if char_length(base) < 3 then
    base := left('leser' || base, 24);
  end if;

  -- Never fail sign-up on a taken name (Google/Apple use the e-mail local part).
  candidate := base;
  while exists (select 1 from public.profiles where lower(username) = candidate) loop
    n := n + 1;
    candidate := base || '_' || n::text;
  end loop;

  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    candidate,
    left(coalesce(nullif(new.raw_user_meta_data->>'display_name', ''), candidate), 50)
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.username_available(p_username text)
returns boolean language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from public.profiles where lower(username) = lower(trim(p_username))
  );
$$;

revoke all on function public.username_available(text) from public;
grant execute on function public.username_available(text) to anon, authenticated;

-- =====================================================================
-- Length limits (NOT VALID: legacy rows untouched, new writes enforced)
-- =====================================================================
alter table public.profiles
  add constraint profiles_display_name_len check (display_name is null or char_length(display_name) <= 50) not valid,
  add constraint profiles_bio_len check (bio is null or char_length(bio) <= 300) not valid;
alter table public.posts
  add constraint posts_content_len check (char_length(content) between 1 and 5000) not valid;
alter table public.comments
  add constraint comments_content_len check (char_length(content) between 1 and 2000) not valid;
alter table public.groups
  add constraint groups_name_len check (char_length(name) between 1 and 80) not valid,
  add constraint groups_description_len check (description is null or char_length(description) <= 500) not valid;
alter table public.group_members
  add constraint group_members_role_valid check (role in ('member', 'admin')) not valid;
alter table public.reports
  add constraint reports_reason_len check (char_length(reason) between 1 and 1000) not valid;
alter table public.books
  add constraint books_title_len check (char_length(title) <= 500) not valid,
  add constraint books_cover_openlibrary check (cover_url is null or cover_url like 'https://covers.openlibrary.org/%') not valid;

-- =====================================================================
-- Storage: size/type limits, owners can delete post images
-- =====================================================================
update storage.buckets
set file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id in ('avatars', 'post-images');

drop policy if exists "Users delete own post images" on storage.objects;
create policy "Users delete own post images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'post-images' and (storage.foldername(name))[1] = auth.uid()::text);

-- =====================================================================
-- Account deletion moved to Edge Function `delete-account` (Storage API + admin API).
-- =====================================================================
drop function if exists public.delete_own_account();
```

- [ ] **Step 2: Self-Check.** Gegen die alten Migrationen prüfen, dass jeder `drop policy`-Name exakt existiert. Sonst bleibt die alte Policy stehen, und Policies sind OR-verknüpft, also bliebe die Lücke offen:

```bash
for p in "Groups visible to members or public" "Users can create groups" "Creators update own groups" "Group members are public" "Users manage own membership" "Posts visible by visibility rules" "Users create own posts" "Users update own posts" "Comments are public" "Users create own comments" "Likes are public" "Users manage own likes" "Follows are public" "Users manage own follows" "Profiles are viewable by everyone" "Users can update own profile" "User genres are public" "User books are public" "Books are public"; do
  grep -q "\"$p\"" supabase/migrations/2026070*.sql supabase/migrations/202607311*.sql || echo "MISSING: $p"
done
```

Expected: keine Ausgabe

- [ ] **Step 3: Commit (nach OK)**

```bash
git add supabase/migrations/20261016120000_security_hardening.sql
git commit -m "feat(db): harden RLS, server-side blocking, invite codes, constraints, storage limits"
```

---

### Task 11: RLS-Regressionstest

**Files:**
- Create: `supabase/tests/rls_smoke.sql`

- [ ] **Step 1: Testskript** (komplette Datei; läuft in einer Transaktion und rollt alles zurück):

```sql
-- RLS smoke test. Run in SQL editor or via MCP execute_sql on the DEV project.
-- Everything is rolled back. Expect final row: ALL RLS CHECKS PASSED
begin;

-- Fixtures (as postgres: bypasses RLS)
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000000a', 'alice@rls.test', '{"username":"alice_rls"}'),
  ('00000000-0000-4000-8000-00000000000b', 'bob@rls.test',   '{"username":"bob_rls"}'),
  ('00000000-0000-4000-8000-00000000000c', 'carol@rls.test', '{"username":"Alice_RLS"}');

insert into public.groups (id, creator_id, name, is_private, invite_code) values
  ('00000000-0000-4000-8000-0000000001a0', '00000000-0000-4000-8000-00000000000a', 'Geheimzirkel', true, 'testcode01'),
  ('00000000-0000-4000-8000-0000000001b0', '00000000-0000-4000-8000-00000000000a', 'Offener Kreis', false, 'testcode02');
insert into public.group_members (group_id, user_id, role) values
  ('00000000-0000-4000-8000-0000000001a0', '00000000-0000-4000-8000-00000000000a', 'admin'),
  ('00000000-0000-4000-8000-0000000001b0', '00000000-0000-4000-8000-00000000000a', 'admin');
insert into public.posts (id, author_id, group_id, content) values
  ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-0000000001a0', 'geheim'),
  ('00000000-0000-4000-8000-0000000002b0', '00000000-0000-4000-8000-00000000000a', null, 'öffentlich');
insert into public.comments (post_id, author_id, content) values
  ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000a', 'geheimer kommentar');
insert into public.likes (post_id, user_id) values
  ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000a');

do $$
declare carol_name text;
begin
  select username into carol_name from public.profiles where id = '00000000-0000-4000-8000-00000000000c';
  if carol_name <> 'alice_rls_1' then
    raise exception 'FAIL trigger: expected alice_rls_1, got %', carol_name;
  end if;
end $$;

-- ---------------- as BOB (outsider) ----------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);

do $$
begin
  if exists (select 1 from public.groups where id = '00000000-0000-4000-8000-0000000001a0') then
    raise exception 'FAIL: bob sees private group'; end if;
  if exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002a0') then
    raise exception 'FAIL: bob sees private post'; end if;
  if exists (select 1 from public.comments where post_id = '00000000-0000-4000-8000-0000000002a0') then
    raise exception 'FAIL: bob sees private comment'; end if;
  if exists (select 1 from public.likes where post_id = '00000000-0000-4000-8000-0000000002a0') then
    raise exception 'FAIL: bob sees private like'; end if;
  if exists (select 1 from public.group_members where group_id = '00000000-0000-4000-8000-0000000001a0') then
    raise exception 'FAIL: bob sees private members'; end if;

  begin
    insert into public.group_members (group_id, user_id, role)
    values ('00000000-0000-4000-8000-0000000001a0', '00000000-0000-4000-8000-00000000000b', 'member');
    raise exception 'FAIL: bob self-joined private group';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.group_members (group_id, user_id, role)
    values ('00000000-0000-4000-8000-0000000001b0', '00000000-0000-4000-8000-00000000000b', 'admin');
    raise exception 'FAIL: bob joined public group as admin';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.posts (author_id, group_id, content)
    values ('00000000-0000-4000-8000-00000000000b', '00000000-0000-4000-8000-0000000001a0', 'spam');
    raise exception 'FAIL: bob posted into private group';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.comments (post_id, author_id, content)
    values ('00000000-0000-4000-8000-0000000002a0', '00000000-0000-4000-8000-00000000000b', 'spam');
    raise exception 'FAIL: bob commented on invisible post';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.posts (author_id, content)
    values ('00000000-0000-4000-8000-00000000000b', repeat('x', 5001));
    raise exception 'FAIL: oversized post accepted';
  exception when check_violation then null;
  end;

  -- allowed: join public group as member
  insert into public.group_members (group_id, user_id, role)
  values ('00000000-0000-4000-8000-0000000001b0', '00000000-0000-4000-8000-00000000000b', 'member');

  -- allowed: join private group via invite code (case-insensitive)
  if public.join_group_with_code(' TESTCODE01 ') <> '00000000-0000-4000-8000-0000000001a0' then
    raise exception 'FAIL: invite join returned wrong group'; end if;
  if not exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002a0') then
    raise exception 'FAIL: member cannot see private post after invite'; end if;

  if public.username_available('ALICE_rls') then
    raise exception 'FAIL: username_available is case-sensitive'; end if;
end $$;

-- ---------------- as ALICE: follow, then block bob ----------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
do $$
begin
  insert into public.follows (follower_id, following_id)
  values ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-00000000000b');
  insert into public.blocks (blocker_id, blocked_id)
  values ('00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-00000000000b');
  if exists (select 1 from public.follows
             where follower_id = '00000000-0000-4000-8000-00000000000a'
               and following_id = '00000000-0000-4000-8000-00000000000b') then
    raise exception 'FAIL: follow survived block'; end if;
end $$;

-- ---------------- as BOB (blocked) ----------------
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);
do $$
begin
  if exists (select 1 from public.posts where id = '00000000-0000-4000-8000-0000000002b0') then
    raise exception 'FAIL: blocked bob sees alice post'; end if;
  begin
    insert into public.follows (follower_id, following_id)
    values ('00000000-0000-4000-8000-00000000000b', '00000000-0000-4000-8000-00000000000a');
    raise exception 'FAIL: blocked bob followed alice';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.likes (post_id, user_id)
    values ('00000000-0000-4000-8000-0000000002b0', '00000000-0000-4000-8000-00000000000b');
    raise exception 'FAIL: blocked bob liked alice post';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---------------- as ANON ----------------
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
  if exists (select 1 from public.profiles) then
    raise exception 'FAIL: anon reads profiles'; end if;
  if exists (select 1 from public.posts) then
    raise exception 'FAIL: anon reads posts'; end if;
  if not public.username_available('niemand_hier_123') then
    raise exception 'FAIL: anon cannot check username availability'; end if;
end $$;

select 'ALL RLS CHECKS PASSED' as result;
rollback;
```

- [ ] **Step 2: Gegenprobe vor der Migration (nach OK).** Das Skript per MCP `execute_sql` auf Dev ausführen, **bevor** Task 10 angewendet ist.
Expected: Abbruch mit einer `FAIL…`-Meldung oder einem Fehler wegen fehlender `invite_code`-Spalte bzw. Funktion. Das belegt, dass der Test die Lücke erkennt.

- [ ] **Step 3: Commit (nach OK)**

```bash
git add supabase/tests/rls_smoke.sql
git commit -m "test(db): add RLS smoke test for groups, blocks, anon access and constraints"
```

---

### Task 12: Edge Function `delete-account` + Client

**Files:**
- Create: `supabase/functions/delete-account/index.ts`
- Modify: `lib/features/auth/providers/auth_provider.dart` (`deleteAccount`)

- [ ] **Step 1: Function** (`supabase/functions/delete-account/index.ts`):

```ts
// Deletes the caller's storage files and auth user (Apple 5.1.1(v), GDPR Art. 17).
// Uses the Storage API: direct SQL deletes on storage.objects orphan files / are blocked.
import { createClient } from 'npm:@supabase/supabase-js@2';

const BUCKETS = ['avatars', 'post-images'];
const MAX_BATCHES = 50;

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return new Response('Unauthorized', { status: 401 });

  const url = Deno.env.get('SUPABASE_URL')!;
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return new Response('Unauthorized', { status: 401 });

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  for (const bucket of BUCKETS) {
    // Re-list from offset 0 after each removal until the user's folder is empty.
    for (let batch = 0; batch < MAX_BATCHES; batch++) {
      const { data: files, error } = await admin.storage.from(bucket).list(user.id, { limit: 100 });
      if (error) return new Response(`Storage list failed: ${error.message}`, { status: 500 });
      if (!files || files.length === 0) break;
      const { error: removeError } = await admin.storage
        .from(bucket)
        .remove(files.map((f) => `${user.id}/${f.name}`));
      if (removeError) return new Response(`Storage remove failed: ${removeError.message}`, { status: 500 });
    }
  }

  // Cascades to profiles, posts, comments, likes, follows, memberships, blocks, reports.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return new Response(`Delete failed: ${deleteError.message}`, { status: 500 });

  return new Response(JSON.stringify({ deleted: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
```

- [ ] **Step 2: Client.** `deleteAccount` ersetzen durch:

```dart
  Future<void> deleteAccount() async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('Nicht angemeldet.');
    }
    try {
      await _client.functions.invoke('delete-account', method: HttpMethod.post);
    } on FunctionException catch (e) {
      debugPrint('delete-account failed: ${e.status} ${e.details}');
      throw const AuthException(
        'Konto konnte nicht gelöscht werden. Bitte später erneut versuchen.',
      );
    }
    await _googleSignIn?.signOut();
    // The server-side user is gone; only clear the local session.
    await _client.auth.signOut(scope: SignOutScope.local);
  }
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit (nach OK)**

```bash
git add supabase/functions/delete-account/index.ts lib/features/auth/providers/auth_provider.dart
git commit -m "feat(account): delete account via edge function using Storage and admin APIs"
```

---

### Task 13: Client an neue Policies anpassen (Invite-Code, Upserts, Bild-Cleanup)

**Files:**
- Modify: `lib/models/group.dart`
- Create: `test/models/group_test.dart`
- Modify: `lib/repositories/group_repository.dart:77-97`
- Modify: `lib/repositories/post_repository.dart:100-109`
- Modify: `lib/repositories/follow_repository.dart:28-31`
- Modify: `lib/features/groups/presentation/group_detail_screen.dart`
- Modify: `lib/features/groups/presentation/groups_screen.dart`

- [ ] **Step 1: Failing Test** (`test/models/group_test.dart`):

```dart
import 'package:booksquad/models/group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BookGroup parses invite code and membership', () {
    final group = BookGroup.fromJson({
      'id': 'g1',
      'creator_id': 'u1',
      'name': 'Geheimzirkel',
      'is_private': true,
      'invite_code': 'abc123def0',
      'created_at': '2026-10-16T10:00:00Z',
      'group_members': [
        {'user_id': 'u1'},
        {'user_id': 'u2'},
      ],
    }, currentUserId: 'u2');

    expect(group.inviteCode, 'abc123def0');
    expect(group.memberCount, 2);
    expect(group.isMember, isTrue);
  });
}
```

- [ ] **Step 2: Fehlschlag prüfen**

Run: `flutter test test/models/group_test.dart`
Expected: FAIL: `The getter 'inviteCode' isn't defined`

- [ ] **Step 3: Modell.** In `BookGroup`:
  - Konstruktor-Parameter `this.inviteCode,` hinzufügen
  - Feld `final String? inviteCode;` hinzufügen
  - in `copyWith` `inviteCode: inviteCode,` übergeben
  - in `fromJson` `inviteCode: json['invite_code'] as String?,` setzen

- [ ] **Step 4: Test grün**

Run: `flutter test test/models/group_test.dart`
Expected: PASS

- [ ] **Step 5: GroupRepository.** In `createGroup` das `upsert` durch `insert` ersetzen, `joinGroup` anpassen und `joinWithCode` hinzufügen:

```dart
    await _client.from('group_members').insert({
      'group_id': inserted['id'],
      'user_id': creatorId,
      'role': 'admin',
    });
```

```dart
  Future<void> joinGroup({
    required String groupId,
    required String userId,
  }) async {
    // ON CONFLICT DO NOTHING: RLS has no UPDATE policy on memberships.
    await _client.from('group_members').upsert(
      {'group_id': groupId, 'user_id': userId, 'role': 'member'},
      ignoreDuplicates: true,
    );
  }

  /// Joins a (private) group by invite code; returns the group id.
  Future<String> joinWithCode(String code) async {
    final result = await _client.rpc(
      'join_group_with_code',
      params: {'code': code},
    );
    return result as String;
  }
```

- [ ] **Step 6: Likes und Follows.** `post_repository.dart` `likePost`:

```dart
    await _client.from('likes').upsert(
      {'post_id': postId, 'user_id': userId},
      ignoreDuplicates: true,
    );
```

`follow_repository.dart` `follow`:

```dart
    await _client.from('follows').upsert(
      {'follower_id': followerId, 'following_id': followingId},
      ignoreDuplicates: true,
    );
```

- [ ] **Step 7: Post-Bild beim Löschen entfernen.** `deletePost` ersetzen:

```dart
  Future<void> deletePost(String postId) async {
    final row = await _client
        .from('posts')
        .select('image_url')
        .eq('id', postId)
        .maybeSingle();
    await _client.from('posts').delete().eq('id', postId);

    final imageUrl = row?['image_url'] as String?;
    if (imageUrl == null) return;
    final path = Uri.parse(imageUrl)
        .pathSegments
        .skipWhile((segment) => segment != 'post-images')
        .skip(1)
        .join('/');
    if (path.isNotEmpty) {
      await _client.storage.from('post-images').remove([path]);
    }
  }
```

- [ ] **Step 8: Gruppen-Detail zeigt dem Ersteller den Code.** In `group_detail_screen.dart` direkt nach dem `Padding` mit `'${item.memberCount} Mitglieder'` einfügen:

```dart
                    if (isCreator && item.isPrivate && item.inviteCode != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.key_outlined),
                        title: const Text('Einladungscode'),
                        subtitle: SelectableText(item.inviteCode!),
                        trailing: IconButton(
                          tooltip: 'Code kopieren',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: item.inviteCode!));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code kopiert')),
                              );
                            }
                          },
                        ),
                      ),
```

Import: `import 'package:flutter/services.dart';`

- [ ] **Step 9: Gruppen-Liste bekommt „Mit Code beitreten“.** In `_GroupsScreenState` nach `_createGroup` hinzufügen:

```dart
  Future<void> _joinWithCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mit Code beitreten'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Einladungscode'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Beitreten'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    try {
      final groupId = await ref.read(groupRepositoryProvider).joinWithCode(code);
      ref.invalidate(groupsProvider(_query));
      if (mounted) context.push('/groups/$groupId');
    } on PostgrestException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ungültiger Einladungscode.')),
        );
      }
    }
  }
```

Im `build`, in der Header-`Row` vor dem `ElevatedButton` „Neu“:

```dart
              TextButton(onPressed: _joinWithCode, child: const Text('Code')),
              const SizedBox(width: 8),
```

Import: `import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;`

- [ ] **Step 10: Analyze + Tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` und `All tests passed!`

- [ ] **Step 11: Commit (nach OK)**

```bash
git add lib/models/group.dart test/models/group_test.dart lib/repositories/ lib/features/groups/
git commit -m "feat(groups): invite codes for private groups; adapt client to stricter RLS"
```

---

### Task 14: Bilder ohne EXIF/GPS, begrenzte Größe

**Files:**
- Modify: `pubspec.yaml` (dependency `image`)
- Create: `lib/core/utils/image_sanitizer.dart`
- Create: `test/core/utils/image_sanitizer_test.dart`
- Modify: `lib/features/feed/presentation/create_post_screen.dart:61-66`
- Modify: `lib/features/profile/presentation/edit_profile_screen.dart:97-101`

- [ ] **Step 1: Dependency**

Run: `flutter pub add image`
Expected: `image: ^4.x` in `pubspec.yaml`

- [ ] **Step 2: Failing Test** (`test/core/utils/image_sanitizer_test.dart`):

```dart
import 'dart:typed_data';

import 'package:booksquad/core/utils/image_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('removes EXIF and caps the long edge', () async {
    final source = img.Image(width: 3000, height: 1000);
    source.exif.imageIfd['Make'] = 'SpyCam';
    final jpg = img.encodeJpg(source);
    expect(img.decodeJpgExif(jpg)?.imageIfd['Make'], isNotNull, reason: 'fixture must carry EXIF');

    final out = await sanitizeImage(Uint8List.fromList(jpg));

    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, 2048);
    expect(decoded.height, closeTo(683, 1));
    expect(decoded.exif.imageIfd['Make'], isNull);
  });

  test('leaves small images at their size', () async {
    final out = await sanitizeImage(
      Uint8List.fromList(img.encodeJpg(img.Image(width: 400, height: 300))),
      maxEdge: 512,
    );
    expect(img.decodeJpg(out)!.width, 400);
  });
}
```

- [ ] **Step 3: Fehlschlag prüfen**

Run: `flutter test test/core/utils/image_sanitizer_test.dart`
Expected: FAIL: `Target of URI doesn't exist`. Falls stattdessen die EXIF-Fixture-Zeile scheitert, hat die `image`-API eine andere Schreibweise für EXIF-Tags. Dann den Fixture-Teil an die API-Doku von `ExifData`/`IfdDirectory` der installierten Version anpassen, ohne die Assertions abzuschwächen.

- [ ] **Step 4: Implementieren** (`lib/core/utils/image_sanitizer.dart`):

```dart
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Re-encodes as JPEG without EXIF (GPS, device) and caps the long edge.
Future<Uint8List> sanitizeImage(Uint8List bytes, {int maxEdge = 2048}) =>
    compute(_sanitize, (bytes, maxEdge));

Uint8List _sanitize((Uint8List, int) args) {
  final (bytes, maxEdge) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Bild konnte nicht gelesen werden.');
  }
  var image = img.bakeOrientation(decoded);
  if (image.width > maxEdge || image.height > maxEdge) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxEdge)
        : img.copyResize(image, height: maxEdge);
  }
  image.exif = img.ExifData();
  return img.encodeJpg(image, quality: 85);
}
```

- [ ] **Step 5: Test grün**

Run: `flutter test test/core/utils/image_sanitizer_test.dart`
Expected: PASS (2 Tests)

- [ ] **Step 6: Create-Post.** `_pickImage` ersetzen:

```dart
  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return;
    final bytes = await sanitizeImage(await file.readAsBytes());
    setState(() => _imageBytes = bytes);
  }
```

Import: `import '../../../core/utils/image_sanitizer.dart';`

- [ ] **Step 7: Avatar.** In `edit_profile_screen.dart` `_pickAvatar` (Zeilen 95–103) ersetzen:

```dart
  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (image == null) return;
    final bytes = await sanitizeImage(await image.readAsBytes(), maxEdge: 512);
    if (mounted) setState(() => _avatarBytes = bytes);
  }
```

Import: `import '../../../core/utils/image_sanitizer.dart';`

- [ ] **Step 8: Analyze + Tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` und `All tests passed!`

- [ ] **Step 9: Commit (nach OK)**

```bash
git add pubspec.yaml pubspec.lock lib/core/utils/image_sanitizer.dart test/core/utils/image_sanitizer_test.dart lib/features/feed/presentation/create_post_screen.dart lib/features/profile/presentation/edit_profile_screen.dart
git commit -m "fix(privacy): strip EXIF/GPS and cap image size before upload"
```

---

### Task 15: DB-Limits im UI spiegeln

**Files:**
- Modify: `lib/core/constants/app_config.dart`
- Modify: `create_post_screen.dart:141`, `post_detail_screen.dart:162`, `edit_profile_screen.dart:173,178`, `onboarding_screen.dart:218,224`, `groups_screen.dart:33,37`, `moderation_actions.dart:21`

- [ ] **Step 1: Konstanten** am Ende von `app_config.dart`:

```dart
/// Mirrors CHECK constraints in 20261016120000_security_hardening.sql.
class AppLimits {
  AppLimits._();

  static const displayName = 50;
  static const bio = 300;
  static const postContent = 5000;
  static const comment = 2000;
  static const groupName = 80;
  static const groupDescription = 500;
  static const reportReason = 1000;
}
```

- [ ] **Step 2: `maxLength` setzen.** In jedem genannten `TextField` direkt unter der `controller:`-Zeile ergänzen:

| Datei:Zeile | Zeile einfügen |
|---|---|
| `create_post_screen.dart:142` | `maxLength: AppLimits.postContent,` |
| `post_detail_screen.dart:163` | `maxLength: AppLimits.comment,` |
| `edit_profile_screen.dart:174` | `maxLength: AppLimits.displayName,` |
| `edit_profile_screen.dart:179` | `maxLength: AppLimits.bio,` |
| `onboarding_screen.dart:219` | `maxLength: AppLimits.displayName,` |
| `onboarding_screen.dart:225` | `maxLength: AppLimits.bio,` |
| `groups_screen.dart:34` | `maxLength: AppLimits.groupName,` |
| `groups_screen.dart:38` | `maxLength: AppLimits.groupDescription,` |
| `moderation_actions.dart:22` | `maxLength: AppLimits.reportReason,` |

Fehlende Imports ergänzen: `import '<relativer Pfad>/core/constants/app_config.dart';`. Nur dort ergänzen, wo `flutter analyze` `Undefined name 'AppLimits'` meldet.

- [ ] **Step 3: Analyze + Tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` und `All tests passed!`

- [ ] **Step 4: Commit (nach OK)**

```bash
git add lib/
git commit -m "feat(ui): enforce DB length limits in text fields"
```

---

### Task 16: Auf Dev anwenden & verifizieren (nach OK)

**Files:** keine Codeänderung

- [ ] **Step 1: Migration anwenden.** Per MCP `apply_migration` (`project_id: thkfqvvzldkfxaqehjqn`, name `security_hardening`, Inhalt aus Task 10).
Expected: Erfolg. Bei einem Fehler wegen doppelter Usernames im Unique-Index: Duplikate mit `select lower(username), count(*) from profiles group by 1 having count(*) > 1;` finden und mit Marcello klären.

- [ ] **Step 2: RLS-Test.** `supabase/tests/rls_smoke.sql` per `execute_sql` ausführen.
Expected: letzte Zeile `ALL RLS CHECKS PASSED`

- [ ] **Step 3: Advisors.** MCP `get_advisors` mit `type: security`.
Expected: keine neuen Warnungen zu RLS, `search_path` oder exponierten Funktionen. Eventuelle Funde einzeln bewerten.

- [ ] **Step 4: Edge Function deployen.** Per MCP `deploy_edge_function` (`name: delete-account`, Datei aus Task 12, `verify_jwt: true`).

- [ ] **Step 5: Manueller App-Test (Marcello).** Mit zwei eigenen Test-Accounts auf Dev:
  1. Registrierung mit einem Username, den es schon gibt → saubere Meldung „bereits vergeben“.
  2. A erstellt eine private Gruppe → der Code ist sichtbar → B tritt per „Code“ bei → B sieht die Beiträge.
  3. A blockiert B → B sieht A's Posts nicht mehr und kann nicht folgen.
  4. Post mit Bild löschen → die Bild-URL liefert danach 400/404.
  5. B löscht seinen Account → Storage-Ordner `avatars/<B-id>` und `post-images/<B-id>` sind leer, und Registrierung mit derselben E-Mail funktioniert wieder.
  6. Passwort-Reset-Flow aus Task 8 Step 8.

- [ ] **Step 6: iOS- und Android-Build**

```bash
flutter build ios --simulator --debug
flutter build apk --debug
```

Expected: beide erfolgreich

---

### Task 17: Doku aktualisieren

**Files:**
- Modify: `supabase/APPLY_MIGRATIONS.md` (Tabelle + Check)
- Modify: `README.md` (Supabase-Abschnitt)

- [ ] **Step 1: `APPLY_MIGRATIONS.md`.** In der Tabelle Zeile 5 ergänzen:

```markdown
| 5 | `20261016120000_security_hardening.sql` | RLS-Härtung, serverseitiges Blockieren, Einladungscodes, Längenlimits, Storage-Limits. **Entfernt `delete_own_account`** → Edge Function `delete-account` deployen |
```

Unter „Schnell-Check“ ergänzen:

```markdown
## Nach Migration 5

1. `supabase/tests/rls_smoke.sql` im SQL-Editor ausführen → letzte Zeile `ALL RLS CHECKS PASSED`.
2. Edge Function `supabase/functions/delete-account` deployen (Dashboard → Edge Functions oder `supabase functions deploy delete-account`).
3. Auth → URL Configuration → Redirect URLs: `booksquad://auth-callback`.
```

- [ ] **Step 2: README.** Die Migrationsliste um Punkt 4 (`20260731150000_fix_account_deletion.sql`, fehlt aktuell) und Punkt 5 ergänzen.

- [ ] **Step 3: Commit (nach OK)**

```bash
git add supabase/APPLY_MIGRATIONS.md README.md
git commit -m "docs: migration 5, RLS test, edge function and redirect URL setup"
```

---

## Nicht in Phase 1 (bewusst verschoben)

- Report-Queue/Admin-Sicht, Rate Limits, PrivacyInfo.xcprivacy → Phase 2
- Umlaute, Dev-Hinweis am Google-Button, l10n, a11y, Back-Swipe → Phase 3
- Pagination, Count-Queries, optimistische Likes → Phase 4
- Dependency-Majors (Riverpod 3, go_router 18, google_sign_in 7) → nach Phase 3, google_sign_in 7 spätestens mit Phase 2 (echte Google-Konfiguration)
- `.env`-Asset durch `--dart-define-from-file` ersetzen → Phase 5 (Prod-Build-Pipeline)

## Risiken

- **Policies sind OR-verknüpft.** Bleibt eine alte, offene Policy wegen eines Namens-Tippfehlers bestehen, ist die Lücke weiter offen. Abgesichert durch Task 10 Step 2 und den RLS-Test.
- **Gruppen-Mitgliederzahl:** Für private Gruppen sehen Nicht-Mitglieder 0 Mitglieder (gewollt).
- **Supabase-Deep-Link-Verhalten (PKCE + `passwordRecovery`-Event)** ist nur manuell testbar (Task 8 Step 8).
- **`flutter build ios`** endete im Review trotz grünem `xcodebuild` noch mit Code 255. Siehe Task 1 Step 5.
