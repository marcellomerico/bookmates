import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/launch_utils.dart';
import '../../../core/widgets/app_legal_links.dart';
import '../../../core/widgets/post_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/presentation/bookshelf_widget.dart';
import '../../books/providers/books_provider.dart';
import '../../social/providers/social_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account löschen?'),
        content: const Text(
          'Dein Profil, Beiträge und Daten werden dauerhaft entfernt. Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Account löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      ref.invalidate(currentProfileProvider);
      ref.invalidate(authStateProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account wurde gelöscht.')),
        );
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final genres = ref.watch(userGenresProvider);

    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Profil konnte nicht geladen werden.')),
      data: (data) {
        if (data == null) {
          return const Center(child: Text('Kein Profil gefunden.'));
        }
        final stats = ref.watch(profileStatsProvider(data.id));
        final posts = ref.watch(userPostsProvider(data.id));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentProfileProvider);
            ref.invalidate(profileStatsProvider(data.id));
            ref.invalidate(userPostsProvider(data.id));
            ref.invalidate(bookshelfProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Row(
                children: [
                  const Spacer(),
                  UserAvatar(
                    url: data.avatarUrl,
                    name: data.displayName ?? data.username,
                    radius: 34,
                  ),
                  const Spacer(),
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
                error: (_, _) => const Text('Statistiken konnten nicht geladen werden.'),
                data: (value) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatColumn(value: '${value.postCount}', label: 'Beiträge'),
                    InkWell(
                      onTap: () => context.push('/users/${data.id}/followers'),
                      child: _StatColumn(value: '${value.followerCount}', label: 'Follower'),
                    ),
                    InkWell(
                      onTap: () => context.push('/users/${data.id}/following'),
                      child: _StatColumn(value: '${value.followingCount}', label: 'Folgt'),
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
                    children: genreList.map((genre) => Chip(label: Text(genre))).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Profil bearbeiten'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await openSupportEmail();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('E-Mail-App konnte nicht geöffnet werden.')),
                    );
                  }
                },
                icon: const Icon(Icons.mail_outline),
                label: const Text('Support kontaktieren'),
              ),
              const SizedBox(height: 24),
              const AppLegalLinks(),
              const SizedBox(height: 24),
              Text('Meine Beiträge', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...posts.when(
                loading: () => const [Center(child: CircularProgressIndicator())],
                error: (_, _) => const [Text('Beiträge konnten nicht geladen werden.')],
                data: (items) => items.isEmpty
                    ? const [Text('Noch keine Beiträge.', style: TextStyle(color: AppColors.muted))]
                    : items
                        .map((post) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PostCard(post: post),
                            ))
                        .toList(),
              ),
              const SizedBox(height: 24),
              const BookshelfWidget(),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Abmelden'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _deleteAccount(context, ref),
                child: const Text('Account löschen', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
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
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ],
    );
  }
}
