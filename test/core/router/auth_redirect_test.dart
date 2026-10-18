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
}) => authRedirect(
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
    test(
      'goes to splash',
      () => expect(_go('/home', auth: authLoading), '/splash'),
    );
    test(
      'stays on splash',
      () => expect(_go('/splash', auth: authLoading), isNull),
    );
    test('stream error without value -> login', () {
      expect(
        _go(
          '/home',
          auth: AsyncError<AuthState>(Exception('x'), StackTrace.empty),
        ),
        '/login',
      );
    });
  });

  group('signed out', () {
    test(
      'protected route -> login',
      () => expect(_go('/home', auth: signedOutState), '/login'),
    );
    test(
      'splash -> login',
      () => expect(_go('/splash', auth: signedOutState), '/login'),
    );
    for (final route in ['/login', '/register', '/forgot-password']) {
      test(
        '$route is reachable',
        () => expect(_go(route, auth: signedOutState), isNull),
      );
    }
  });

  group('signed in', () {
    test('profile loading without value -> splash', () {
      expect(
        _go('/home', auth: signedInU1, profile: const AsyncLoading()),
        '/splash',
      );
    });
    test('stale profile of previous user while loading -> splash', () {
      const other = Profile(
        id: 'old',
        username: 'old',
        onboardingCompleted: true,
      );
      final stale = const AsyncLoading<Profile?>().copyWithPrevious(
        const AsyncData(other),
      );
      expect(_go('/home', auth: signedInU1, profile: stale), '/splash');
    });
    test('refreshing own profile does not flash splash', () {
      final refreshing = const AsyncLoading<Profile?>().copyWithPrevious(
        const AsyncData(_done),
      );
      expect(_go('/posts/1', auth: signedInU1, profile: refreshing), isNull);
    });
    test(
      'profile load error without own profile -> splash (no onboarding)',
      () {
        final err = AsyncError<Profile?>(Exception('net'), StackTrace.empty);
        expect(_go('/home', auth: signedInU1, profile: err), '/splash');
        expect(_go('/splash', auth: signedInU1, profile: err), isNull);
      },
    );
    test('onboarding incomplete -> onboarding', () {
      expect(
        _go('/home', auth: signedInU1, profile: const AsyncData(_fresh)),
        '/onboarding',
      );
    });
    test('missing profile row -> onboarding', () {
      expect(
        _go('/home', auth: signedInU1, profile: const AsyncData(null)),
        '/onboarding',
      );
    });
    test('book search allowed during onboarding', () {
      expect(
        _go(
          '/books/search',
          auth: signedInU1,
          profile: const AsyncData(_fresh),
        ),
        isNull,
      );
    });
    for (final route in [
      '/login',
      '/register',
      '/splash',
      '/onboarding',
      '/forgot-password',
      '/reset-password',
    ]) {
      test('$route -> home when onboarded', () {
        expect(
          _go(route, auth: signedInU1, profile: const AsyncData(_done)),
          '/home',
        );
      });
    }
    test('deep route stays', () {
      expect(
        _go('/posts/1', auth: signedInU1, profile: const AsyncData(_done)),
        isNull,
      );
    });
  });

  group('password recovery', () {
    test('forces reset screen', () {
      expect(
        _go(
          '/home',
          auth: signedInU1,
          profile: const AsyncData(_done),
          recovering: true,
        ),
        '/reset-password',
      );
    });
    test('reset screen stays', () {
      expect(
        _go(
          '/reset-password',
          auth: signedInU1,
          profile: const AsyncData(_done),
          recovering: true,
        ),
        isNull,
      );
    });
  });
}
