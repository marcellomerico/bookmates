import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/message.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';
import '../providers/messages_providers.dart';

class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nachrichten')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(conversationsProvider),
        child: conversations.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ErrorState(
                message: 'Nachrichten konnten nicht geladen werden.',
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    EmptyState(
                      icon: Icons.mail_outline,
                      title: 'Noch keine Nachrichten',
                      message:
                          'Wenn ihr euch gegenseitig folgt, kannst du über das Profil eine Nachricht schreiben.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ConversationTile(items[i]),
                ),
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile(this.conversation);

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = ref
        .watch(profileByIdProvider(conversation.otherId))
        .valueOrNull;
    final me = ref.watch(currentUserProvider)?.id;
    final name = other?.displayName ?? other?.username ?? '…';
    final mine = conversation.lastSenderId == me;
    final unread = conversation.unread;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(url: other?.avatarUrl, name: name, radius: 22),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${mine ? 'Du: ' : ''}${conversation.lastBody ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread ? context.palette.ink : context.palette.muted,
          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (conversation.lastMessageAt != null)
            Text(
              formatRelativeTime(conversation.lastMessageAt!),
              style: TextStyle(fontSize: 11, color: context.palette.muted),
            ),
          if (unread) ...[
            const SizedBox(height: 4),
            Semantics(
              label: 'Ungelesen',
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () async {
        await context.push(
          '/messages/${conversation.id}?with=${conversation.otherId}',
        );
        ref.invalidate(conversationsProvider);
      },
    );
  }
}
