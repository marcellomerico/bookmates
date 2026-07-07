import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Profil konnte nicht geladen werden.')),
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
