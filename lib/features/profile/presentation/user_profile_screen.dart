import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/moderation_actions.dart';
import '../../../core/widgets/post_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/presentation/bookshelf_widget.dart';
import '../../books/providers/books_provider.dart';
import '../../social/providers/social_providers.dart';

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
      ref.invalidate(feedProvider);
      ref.invalidate(activityProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileByIdProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final stats = ref.watch(profileStatsProvider(userId));
    final genres = ref.watch(userGenresByIdProvider(userId));
    final following = ref.watch(isFollowingProvider(userId));
    final blocked = ref.watch(isBlockedProvider(userId));
    final posts = ref.watch(userPostsProvider(userId));
    final ownProfile = currentUser?.id == userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (!ownProfile && currentUser != null)
            IconButton(
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

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(profileByIdProvider(userId));
                  ref.invalidate(profileStatsProvider(userId));
                  ref.invalidate(userPostsProvider(userId));
                  ref.invalidate(bookshelfByUserProvider(userId));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: UserAvatar(
                        url: data.avatarUrl,
                        name: data.displayName ?? data.username,
                        radius: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.displayName ?? data.username,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '@${data.username}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (data.bio?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(data.bio!, textAlign: TextAlign.center),
                      ),
                    const SizedBox(height: 16),
                    stats.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Text('Statistiken konnten nicht geladen werden.'),
                      data: (value) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Stat('${value.postCount}', 'Beiträge'),
                          InkWell(
                            onTap: () => context.push('/users/$userId/followers'),
                            child: _Stat('${value.followerCount}', 'Follower'),
                          ),
                          InkWell(
                            onTap: () => context.push('/users/$userId/following'),
                            child: _Stat('${value.followingCount}', 'Folgt'),
                          ),
                        ],
                      ),
                    ),
                    if (!ownProfile && currentUser != null) ...[
                      const SizedBox(height: 16),
                      following.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (value) => ElevatedButton(
                          onPressed: () => _toggleFollow(context, ref, currentUser.id, value),
                          child: Text(value ? 'Entfolgen' : 'Folgen'),
                        ),
                      ),
                    ],
                    genres.when(
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: items.map((genre) => Chip(label: Text(genre))).toList(),
                              ),
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 24),
                    Text('Beiträge', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ...posts.when(
                      loading: () => const [Center(child: CircularProgressIndicator())],
                      error: (_, _) => [
                        ErrorState(
                          message: 'Beiträge konnten nicht geladen werden.',
                          onRetry: () => ref.invalidate(userPostsProvider(userId)),
                        ),
                      ],
                      data: (items) => items.isEmpty
                          ? const [
                              EmptyState(
                                icon: Icons.edit_note,
                                title: 'Noch keine Beiträge',
                              ),
                            ]
                          : items
                              .map((post) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: PostCard(post: post),
                                  ))
                              .toList(),
                    ),
                    const SizedBox(height: 24),
                    BookshelfWidget(userId: userId),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      );
}
