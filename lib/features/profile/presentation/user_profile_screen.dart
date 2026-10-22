import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/moderation_actions.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';
import '../../social/providers/paged_posts.dart';
import '../../social/providers/social_providers.dart';
import 'profile_layout.dart';

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    String currentUserId,
    bool following,
  ) async {
    final repo = ref.read(followRepositoryProvider);
    try {
      if (following) {
        await repo.unfollow(followerId: currentUserId, followingId: userId);
      } else {
        await repo.follow(followerId: currentUserId, followingId: userId);
      }
      ref.invalidate(isFollowingProvider(userId));
      ref.invalidate(profileStatsProvider(userId));
      ref.invalidate(pagedPostsProvider);
      ref.invalidate(activityProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final following = ref.watch(isFollowingProvider(userId));
    final blocked = ref.watch(isBlockedProvider(userId));
    final ownProfile = currentUser?.id == userId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          profile.valueOrNull == null
              ? 'Profil'
              : '@${profile.valueOrNull!.username}',
        ),
        actions: [
          if (!ownProfile && currentUser != null)
            IconButton(
              tooltip: 'Optionen',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => profile.whenOrNull(
                data: (data) => data == null
                    ? null
                    : showUserActionsMenu(
                        context,
                        ref,
                        userId: userId,
                        displayName: data.displayName ?? data.username,
                      ),
              ),
            ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Profil konnte nicht geladen werden.',
          onRetry: () => ref.invalidate(profileByIdProvider(userId)),
        ),
        data: (data) {
          if (data == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profil nicht gefunden',
            );
          }

          return blocked.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ErrorState(
              message: 'Profil konnte nicht geladen werden.',
              onRetry: () => ref.invalidate(isBlockedProvider(userId)),
            ),
            data: (isBlocked) {
              if (isBlocked) {
                return const EmptyState(
                  icon: Icons.block,
                  title: 'Du hast diesen Nutzer blockiert',
                );
              }

              return ProfileLayout(
                profile: data,
                own: ownProfile,
                onRefresh: () async {
                  ref.invalidate(profileByIdProvider(userId));
                  ref.invalidate(profileStatsProvider(userId));
                  ref.invalidate(userGenresByIdProvider(userId));
                  ref.invalidate(bookshelfByUserProvider(userId));
                  await ref
                      .read(
                        pagedPostsProvider(PostSource.author(userId)).notifier,
                      )
                      .refresh();
                },
                actions: ownProfile || currentUser == null
                    ? const SizedBox.shrink()
                    : following.when(
                        loading: () => const SizedBox(
                          height: 40,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (value) => SizedBox(
                          width: double.infinity,
                          child: value
                              ? OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                  ),
                                  onPressed: () => _toggleFollow(
                                    context,
                                    ref,
                                    currentUser.id,
                                    value,
                                  ),
                                  child: const Text('Folgst du'),
                                )
                              : FilledButton(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                  ),
                                  onPressed: () => _toggleFollow(
                                    context,
                                    ref,
                                    currentUser.id,
                                    value,
                                  ),
                                  child: const Text('Folgen'),
                                ),
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
