import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/booksquad_ui.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../social/providers/social_providers.dart';
import '../../../core/widgets/verified_badge.dart';

enum FollowListMode { followers, following }

class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.userId, required this.mode});

  final String userId;
  final FollowListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mode == FollowListMode.followers
        ? followersProvider(userId)
        : followingProvider(userId);
    final profiles = ref.watch(provider);
    final title = mode == FollowListMode.followers ? 'Follower' : 'Folgt';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(provider),
        child: profiles.when(
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
                message: 'Liste konnte nicht geladen werden.',
                onRetry: () => ref.invalidate(provider),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    EmptyState(
                      icon: Icons.people_outline,
                      title: 'Keine Leser gefunden',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final profile = items[index];
                    return Reveal(
                      index: math.min(index, 6),
                      child: ListCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => context.push('/users/${profile.id}'),
                          leading: UserAvatar(
                            url: profile.avatarUrl,
                            name: profile.displayName ?? profile.username,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.displayName ?? profile.username,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              VerifiedBadge(profile: profile),
                            ],
                          ),
                          subtitle: Text('@${profile.username}'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
