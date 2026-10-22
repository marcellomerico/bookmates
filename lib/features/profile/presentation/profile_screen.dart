import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/books_provider.dart';
import '../../social/providers/paged_posts.dart';
import '../../social/providers/social_providers.dart';
import 'profile_layout.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return profile.when(
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
        return ProfileLayout(
          profile: data,
          own: true,
          onRefresh: () async {
            ref.invalidate(currentProfileProvider);
            ref.invalidate(profileStatsProvider(data.id));
            ref.invalidate(userGenresByIdProvider(data.id));
            ref.invalidate(bookshelfProvider);
            await ref
                .read(pagedPostsProvider(PostSource.author(data.id)).notifier)
                .refresh();
          },
          actions: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: _compact,
                  onPressed: () => context.push('/profile/edit'),
                  child: const Text('Profil bearbeiten'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 40,
                child: OutlinedButton(
                  style: _compact.copyWith(
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    minimumSize: const WidgetStatePropertyAll(Size.square(40)),
                  ),
                  onPressed: () => context.push('/settings'),
                  child: const Icon(
                    Icons.settings_outlined,
                    size: 20,
                    semanticLabel: 'Einstellungen',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Profile actions are secondary: slimmer than the app-wide 48 pt buttons.
final _compact = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 40),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
);
