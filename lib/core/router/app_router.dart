import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/books/presentation/book_search_screen.dart';
import '../../features/feed/presentation/activity_screen.dart';
import '../../features/feed/presentation/post_detail_screen.dart';
import '../../features/feed/presentation/main_shell.dart';
import '../../features/moderation/presentation/moderation_queue_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/follow_list_screen.dart';
import '../../features/profile/presentation/user_profile_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../models/user_book.dart';
import 'auth_redirect.dart';
import 'bookmates_page_transitions.dart';
import 'splash_screen.dart';

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
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            fadeSlidePage(key: state.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) => fadeSlidePage(
          key: state.pageKey,
          child: const ResetPasswordScreen(),
        ),
      ),
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
        pageBuilder: (context, state) =>
            slidePushPage(key: state.pageKey, child: const ActivityScreen()),
      ),
      GoRoute(
        path: '/moderation',
        pageBuilder: (context, state) => slidePushPage(
          key: state.pageKey,
          child: const ModerationQueueScreen(),
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
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    // First: instantiates passwordRecoveryProvider at startup (no recovery event missed)
    // and lets it react to auth events before the router refresh below runs.
    ref.listen(passwordRecoveryProvider, (_, _) => notifyListeners());
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }
}
