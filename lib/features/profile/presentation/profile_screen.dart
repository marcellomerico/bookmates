import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paged_post_list.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/presentation/bookshelf_widget.dart';
import '../../books/providers/books_provider.dart';
import '../../social/providers/paged_posts.dart';
import '../../social/providers/social_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final genres = ref.watch(userGenresProvider);

    final body = profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => ErrorState(
        message: 'Profil konnte nicht geladen werden.',
        onRetry: () => ref.invalidate(currentProfileProvider),
      ),
      data: (data) {
        if (data == null) {
          return const EmptyState(
            icon: Icons.person_off_outlined,
            title: 'Kein Profil gefunden',
          );
        }
        final stats = ref.watch(profileStatsProvider(data.id));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentProfileProvider);
            ref.invalidate(profileStatsProvider(data.id));
            ref.invalidate(bookshelfProvider);
            await ref
                .read(pagedPostsProvider(PostSource.author(data.id)).notifier)
                .refresh();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mirrors the settings button so the avatar stays centered.
                  const SizedBox(width: 48),
                  const Spacer(),
                  UserAvatar(
                    url: data.avatarUrl,
                    name: data.displayName ?? data.username,
                    radius: 34,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Einstellungen',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.push('/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data.displayName ?? data.username,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (data.username.isNotEmpty)
                Text(
                  '@${data.username}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              if (data.bio != null && data.bio!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(data.bio!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              stats.when(
                loading: () => const SizedBox(
                  height: 52,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) =>
                    const Text('Statistiken konnten nicht geladen werden.'),
                data: (value) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatColumn(value: '${value.postCount}', label: 'Beiträge'),
                    InkWell(
                      onTap: () => context.push('/users/${data.id}/followers'),
                      child: _StatColumn(
                        value: '${value.followerCount}',
                        label: 'Follower',
                      ),
                    ),
                    InkWell(
                      onTap: () => context.push('/users/${data.id}/following'),
                      child: _StatColumn(
                        value: '${value.followingCount}',
                        label: 'Folgt',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              genres.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (genreList) {
                  if (genreList.isEmpty) return const SizedBox.shrink();
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: genreList
                        .map((genre) => Chip(label: Text(genre)))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Profil bearbeiten'),
              ),
              const SizedBox(height: 32),
              // Shelf before posts: the post list pages endlessly, anything below it is unreachable.
              const BookshelfWidget(),
              const SizedBox(height: 24),
              Text(
                'Meine Beiträge',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...pagedPostListItems(
                ref,
                PostSource.author(data.id),
                errorMessage: 'Beiträge konnten nicht geladen werden.',
                empty: const EmptyState(
                  icon: Icons.edit_note,
                  title: 'Noch keine Beiträge',
                  message: 'Teile, was du gerade liest.',
                ),
              ),
            ],
          ),
        );
      },
    );
    return body;
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}
