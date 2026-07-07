import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/feed/presentation/main_shell.dart';

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

      if (state.matchedLocation == '/onboarding') {
        if (profile.isLoading) return null;
        final completed = profile.valueOrNull?.onboardingCompleted ?? false;
        if (completed) return '/home';
        return null;
      }

      if (profile.isLoading) return null;
      final completed = profile.valueOrNull?.onboardingCompleted ?? false;
      if (!completed) return '/onboarding';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: buildMainShellBranches(),
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(currentProfileProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}
