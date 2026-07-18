import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/presentation/bookshelf_widget.dart';
import '../../books/providers/books_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final genres = ref.watch(userGenresProvider);

    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Profil konnte nicht geladen werden.')),
      data: (data) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.parchment,
              child: Text(
                (data?.displayName ?? '?').characters.first.toUpperCase(),
                style: const TextStyle(fontSize: 28, color: AppColors.burgundy),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data?.displayName ?? 'Leser',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (data?.username != null)
              Text(
                '@${data!.username}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            if (data?.bio != null && data!.bio!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(data.bio!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
            const BookshelfWidget(),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Abmelden'),
            ),
          ],
        );
      },
    );
  }
}
