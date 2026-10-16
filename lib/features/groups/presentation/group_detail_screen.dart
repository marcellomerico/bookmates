import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/post_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  Future<void> _toggleMembership(WidgetRef ref, bool member) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(groupRepositoryProvider);
    if (member) {
      await repo.leaveGroup(groupId: groupId, userId: user.id);
    } else {
      await repo.joinGroup(groupId: groupId, userId: user.id);
    }
    ref.invalidate(groupDetailProvider(groupId));
    ref.invalidate(groupsProvider(null));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));
    final posts = ref.watch(groupPostsProvider(groupId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gruppe')),
      floatingActionButton: group.maybeWhen(
        data: (item) => item != null && item.isMember
            ? FloatingActionButton.extended(
                onPressed: () => context.go('/create?groupId=$groupId'),
                icon: const Icon(Icons.edit),
                label: const Text('Beitrag'),
              )
            : null,
        orElse: () => null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupDetailProvider(groupId));
          ref.invalidate(groupPostsProvider(groupId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            group.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('Gruppe konnte nicht geladen werden.'),
              data: (item) {
                if (item == null) return const Text('Gruppe nicht gefunden.');
                final isCreator = currentUser?.id == item.creatorId;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.name, style: Theme.of(context).textTheme.headlineMedium),
                        ),
                        if (item.isPrivate) const Icon(Icons.lock_outline, size: 18),
                      ],
                    ),
                    if (item.description?.isNotEmpty ?? false)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(item.description!)),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${item.memberCount} Mitglieder'),
                    ),
                    const SizedBox(height: 10),
                    if (!item.isMember)
                      OutlinedButton(
                        onPressed: () => _toggleMembership(ref, false),
                        child: const Text('Beitreten'),
                      )
                    else if (!isCreator)
                      OutlinedButton(
                        onPressed: () => _toggleMembership(ref, true),
                        child: const Text('Gruppe verlassen'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Beiträge', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...posts.when(
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (_, _) => const [Text('Beiträge konnten nicht geladen werden.')],
              data: (items) => items.isEmpty
                  ? const [Text('Noch keine Beiträge in dieser Gruppe.')]
                  : items
                      .map(
                        (post) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PostCard(post: post),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
