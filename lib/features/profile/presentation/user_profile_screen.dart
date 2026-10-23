import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/moderation_actions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../repositories/follow_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';
import '../../messages/providers/messages_providers.dart';
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
    FollowState state,
  ) async {
    final repo = ref.read(followRepositoryProvider);
    try {
      if (state == FollowState.none) {
        await repo.follow(followerId: currentUserId, followingId: userId);
      } else {
        await repo.unfollow(followerId: currentUserId, followingId: userId);
      }
      ref.invalidate(followStateProvider(userId));
      ref.invalidate(canMessageProvider(userId));
      ref.invalidate(bookshelfByUserProvider(userId));
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

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    try {
      final id = await ref
          .read(messageRepositoryProvider)
          .startConversation(userId);
      if (context.mounted) context.push('/messages/$id?with=$userId');
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
    final following = ref.watch(followStateProvider(userId));
    final blocked = ref.watch(isBlockedProvider(userId));
    final canMessage =
        ref.watch(canMessageProvider(userId)).valueOrNull ?? false;
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
                locked:
                    data.isPrivate &&
                    !ownProfile &&
                    following.valueOrNull != FollowState.following,
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
                        data: (state) => Row(
                          children: [
                            Expanded(
                              child: state == FollowState.none
                                  ? FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                      ),
                                      onPressed: () => _toggleFollow(
                                        context,
                                        ref,
                                        currentUser.id,
                                        state,
                                      ),
                                      child: Text(
                                        data.isPrivate
                                            ? 'Folgen anfragen'
                                            : 'Folgen',
                                      ),
                                    )
                                  : OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                      ),
                                      onPressed: () => _toggleFollow(
                                        context,
                                        ref,
                                        currentUser.id,
                                        state,
                                      ),
                                      child: Text(
                                        state == FollowState.requested
                                            ? 'Angefragt'
                                            : 'Folgst du',
                                      ),
                                    ),
                            ),
                            if (canMessage) ...[
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                ),
                                onPressed: () => _openChat(context, ref),
                                icon: const Icon(Icons.mail_outline, size: 18),
                                label: const Text('Nachricht'),
                              ),
                            ],
                          ],
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
