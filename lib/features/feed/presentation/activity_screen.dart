import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    final requests = ref.watch(followRequestsProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Aktivität')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activityProvider);
          ref.invalidate(followRequestsProvider);
        },
        child: activity.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (_, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ErrorState(
                message: 'Aktivität konnte nicht geladen werden.',
                onRetry: () => ref.invalidate(activityProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty && requests.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  EmptyState(
                    icon: Icons.notifications_none,
                    title: 'Noch keine Aktivität',
                    message:
                        '„Gefällt mir“-Angaben, Kommentare und neue Follower erscheinen hier.',
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: requests.length + items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index < requests.length) {
                  return _FollowRequestTile(profile: requests[index]);
                }
                final item = items[index - requests.length];
                final name = item.actor.displayName ?? item.actor.username;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(
                    url: item.actor.avatarUrl,
                    name: name,
                    radius: 20,
                  ),
                  title: Text(
                    item.message(name),
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    formatRelativeTime(item.createdAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
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

class _FollowRequestTile extends ConsumerWidget {
  const _FollowRequestTile({required this.profile});

  final Profile profile;

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    bool accept,
  ) async {
    try {
      await ref
          .read(followRepositoryProvider)
          .respondToRequest(profile.id, accept: accept);
      ref.invalidate(followRequestsProvider);
      if (accept) ref.invalidate(activityProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile.displayName ?? profile.username;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(url: profile.avatarUrl, name: name, radius: 20),
      title: Text(
        '$name möchte dir folgen.',
        style: const TextStyle(fontSize: 13),
      ),
      onTap: () => context.push('/users/${profile.id}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Ablehnen',
            icon: const Icon(Icons.close),
            onPressed: () => _respond(context, ref, false),
          ),
          IconButton.filled(
            tooltip: 'Annehmen',
            icon: const Icon(Icons.check),
            onPressed: () => _respond(context, ref, true),
          ),
        ],
      ),
    );
  }
}
