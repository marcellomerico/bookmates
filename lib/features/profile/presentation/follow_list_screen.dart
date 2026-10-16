import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/user_avatar.dart';
import '../../social/providers/social_providers.dart';

enum FollowListMode { followers, following }

class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.userId, required this.mode});

  final String userId;
  final FollowListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(
      mode == FollowListMode.followers
          ? followersProvider(userId)
          : followingProvider(userId),
    );
    final title = mode == FollowListMode.followers ? 'Follower' : 'Folgt';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(
          mode == FollowListMode.followers
              ? followersProvider(userId)
              : followingProvider(userId),
        ),
        child: profiles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('Liste konnte nicht geladen werden.')),
          data: (items) => items.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Keine Leser gefunden.')),
                    ),
                  ],
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final profile = items[index];
                    return ListTile(
                      onTap: () => context.push('/users/${profile.id}'),
                      leading: UserAvatar(
                        url: profile.avatarUrl,
                        name: profile.displayName ?? profile.username,
                      ),
                      title: Text(profile.displayName ?? profile.username),
                      subtitle: Text('@${profile.username}'),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
