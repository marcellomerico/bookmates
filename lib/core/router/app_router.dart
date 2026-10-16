import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/books/presentation/book_search_screen.dart';
import '../../features/feed/presentation/activity_screen.dart';
import '../../features/feed/presentation/post_detail_screen.dart';
import '../../features/feed/presentation/main_shell.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/follow_list_screen.dart';
import '../../features/profile/presentation/user_profile_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../models/user_book.dart';
import 'bookmates_page_transitions.dart';

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
      final onAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn) {
        return onAuthRoute ? null : '/login';
      }

      if (onAuthRoute) {
        if (profile.isLoading) return null;
        final completed = profile.valueOrNull?.onboardingCompleted ?? false;
        return completed ? '/home' : '/onboarding';
      }

      // Routes allowed before onboarding is finished (nested flows).
      final onboardingAllowed =
          state.matchedLocation == '/onboarding' ||
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
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const RegisterScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => fadeSlidePage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/activity',
        pageBuilder: (context, state) => slidePushPage(
          key: state.pageKey,
          child: const ActivityScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (context, state) =>
            slidePushPage(key: state.pageKey, child: const EditProfileScreen()),
      ),
      GoRoute(
        path: '/books/search',
        pageBuilder: (context, state) {
          final statusParam = state.uri.queryParameters['status'];
          final fromOnboarding =
              state.uri.queryParameters['onboarding'] == 'true';
          return slidePushPage(
            key: state.pageKey,
            child: BookSearchScreen(
              initialStatus: statusParam != null
                  ? BookStatus.fromDb(statusParam)
                  : BookStatus.wantToRead,
              fromOnboarding: fromOnboarding,
            ),
          );
        },
      ),
      GoRoute(
        path: '/posts/:postId',
        pageBuilder: (context, state) => slidePushPage(
          key: state.pageKey,
          child: PostDetailScreen(postId: state.pathParameters['postId']!),
        ),
      ),
      GoRoute(
        path: '/users/:userId',
        pageBuilder: (context, state) => slidePushPage(
          key: state.pageKey,
          child: UserProfileScreen(userId: state.pathParameters['userId']!),
        ),
      ),
      GoRoute(
        path: '/users/:userId/followers',
        pageBuilder: (context, state) => slidePushPage(
          key: state.pageKey,
          child: FollowListScreen(
            userId: state.pathParameters['userId']!,
            mode: FollowListMode.followers,
          ),
        ),
      ),
      GoRoute(
        path: '/users/:userId/following',
        pageBuilder: (context, state) => slidePushPage(
          key: state.pageKey,
          child: FollowListScreen(
            userId: state.pathParameters['userId']!,
            mode: FollowListMode.following,
          ),
        ),
      ),
      GoRoute(
        path: '/groups/:groupId',
        pageBuilder: (context, state) => slidePushPage(
          key: state.pageKey,
          child: GroupDetailScreen(groupId: state.pathParameters['groupId']!),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MainShell(navigationShell: navigationShell),
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
