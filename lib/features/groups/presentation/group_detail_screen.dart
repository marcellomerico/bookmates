import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/post_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  Future<void> _toggleMembership(BuildContext context, WidgetRef ref, bool member) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(groupRepositoryProvider);
    try {
      if (member) {
        await repo.leaveGroup(groupId: groupId, userId: user.id);
      } else {
        await repo.joinGroup(groupId: groupId, userId: user.id);
      }
      ref.invalidate(groupDetailProvider(groupId));
      ref.invalidate(groupsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));
    final posts = ref.watch(groupPostsProvider(groupId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lesekreis')),
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            group.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorState(
                message: 'Lesekreis konnte nicht geladen werden.',
                onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
              ),
              data: (item) {
                if (item == null) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'Lesekreis nicht gefunden',
                  );
                }
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
                    if (isCreator && item.isPrivate && item.inviteCode != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.key_outlined),
                        title: const Text('Einladungscode'),
                        subtitle: SelectableText(item.inviteCode!),
                        trailing: IconButton(
                          tooltip: 'Code kopieren',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: item.inviteCode!));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code kopiert')),
                              );
                            }
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (!item.isMember)
                      OutlinedButton(
                        onPressed: () => _toggleMembership(context, ref, false),
                        child: const Text('Beitreten'),
                      )
                    else if (!isCreator)
                      OutlinedButton(
                        onPressed: () => _toggleMembership(context, ref, true),
                        child: const Text('Lesekreis verlassen'),
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
              error: (_, _) => [
                ErrorState(
                  message: 'Beiträge konnten nicht geladen werden.',
                  onRetry: () => ref.invalidate(groupPostsProvider(groupId)),
                ),
              ],
              data: (items) => items.isEmpty
                  ? const [
                      EmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Noch keine Beiträge',
                        message: 'In diesem Lesekreis gibt es noch keine Beiträge.',
                      ),
                    ]
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
