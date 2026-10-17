import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../social/providers/social_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aktivität')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(activityProvider),
        child: activity.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Aktivität konnte nicht geladen werden.')),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Noch keine Aktivität.\nLikes, Kommentare und neue Follower erscheinen hier.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final name = item.actor.displayName ?? item.actor.username;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(
                    url: item.actor.avatarUrl,
                    name: name,
                    radius: 20,
                  ),
                  title: Text(item.message(name), style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    formatRelativeTime(item.createdAt),
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  onTap: () {
                    if (item.postId != null) {
                      context.push('/posts/${item.postId}');
                    } else {
                      context.push('/users/${item.actor.id}');
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
