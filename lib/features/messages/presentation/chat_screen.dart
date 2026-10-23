import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/moderation_actions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/message.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';
import '../providers/messages_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherId,
  });

  final String conversationId;
  final String otherId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(messageRepositoryProvider)
          .send(widget.conversationId, text);
      _input.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = ref.watch(profileByIdProvider(widget.otherId)).valueOrNull;
    final canSend = ref.watch(canMessageProvider(widget.otherId)).valueOrNull;
    final me = ref.watch(currentUserProvider)?.id;
    final messages = ref.watch(messagesProvider(widget.conversationId));

    // Every new batch while the chat is open counts as read.
    ref.listen(messagesProvider(widget.conversationId), (_, next) {
      if (next.hasValue) {
        ref
            .read(messageRepositoryProvider)
            .markRead(widget.conversationId)
            .ignore();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => context.push('/users/${widget.otherId}'),
          child: Text(other?.displayName ?? other?.username ?? 'Nachricht'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => ErrorState(
                message: 'Nachrichten konnten nicht geladen werden.',
                onRetry: () =>
                    ref.invalidate(messagesProvider(widget.conversationId)),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.waving_hand_outlined,
                      title: 'Sag Hallo',
                      message:
                          'Worüber wollt ihr reden? Vielleicht das letzte Buch?',
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final m = list[list.length - 1 - i];
                        return _Bubble(message: m, mine: m.senderId == me);
                      },
                    ),
            ),
          ),
          if (canSend == false)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ihr folgt euch nicht mehr gegenseitig. Neue Nachrichten sind erst wieder möglich, wenn ihr euch beide folgt.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Nachricht schreiben',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Senden',
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine
            ? null
            : () => showReportDialog(
                context,
                ref,
                reportedUserId: message.senderId,
                quote: message.body,
              ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: mine ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            message.body,
            style: TextStyle(color: mine ? scheme.onPrimary : AppColors.ink),
          ),
        ),
      ),
    );
  }
}
