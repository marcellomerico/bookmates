import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/message.dart';
import '../../../repositories/message_repository.dart';
import '../../auth/providers/auth_provider.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(supabaseClientProvider));
});

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationSummary>>((ref) async {
      if (ref.watch(currentUserProvider) == null) return [];
      return ref.watch(messageRepositoryProvider).getConversations();
    });

final hasUnreadMessagesProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(conversationsProvider).valueOrNull?.any((c) => c.unread) ??
      false,
);

final messagesProvider = StreamProvider.autoDispose
    .family<List<Message>, String>(
      (ref, conversationId) =>
          ref.watch(messageRepositoryProvider).watchMessages(conversationId),
    );

final canMessageProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  otherId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || user.id == otherId) return false;
  return ref.watch(messageRepositoryProvider).isMutual(user.id, otherId);
});
