import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/books/presentation/book_search_screen.dart';
import '../../features/feed/presentation/main_shell.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../models/user_book.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profile = ref.watch(currentProfileProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefresh(ref),
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final session = authState.valueOrNull?.session;
      final isLoggedIn = session != null;
      final onAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isLoggedIn) {
        return onAuthRoute ? null : '/login';
      }

      if (onAuthRoute) {
        if (profile.isLoading) return null;
        final completed = profile.valueOrNull?.onboardingCompleted ?? false;
        return completed ? '/home' : '/onboarding';
      }

      // Routes allowed before onboarding is finished (nested flows).
      final onboardingAllowed = state.matchedLocation == '/onboarding' ||
          state.matchedLocation == '/books/search';

      if (state.matchedLocation == '/onboarding') {
        if (profile.isLoading) return null;
        final completed = profile.valueOrNull?.onboardingCompleted ?? false;
        if (completed) return '/home';
        return null;
      }

      if (profile.isLoading) return null;
      final completed = profile.valueOrNull?.onboardingCompleted ?? false;
      if (!completed && !onboardingAllowed) return '/onboarding';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
      GoRoute(
        path: '/books/search',
        builder: (context, state) {
          final statusParam = state.uri.queryParameters['status'];
          final fromOnboarding = state.uri.queryParameters['onboarding'] == 'true';
          return BookSearchScreen(
            initialStatus: statusParam != null
                ? BookStatus.fromDb(statusParam)
                : BookStatus.wantToRead,
            fromOnboarding: fromOnboarding,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: buildMainShellBranches(),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}
