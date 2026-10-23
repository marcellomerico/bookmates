import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';

class MessageRepository {
  MessageRepository(this._client);

  final SupabaseClient _client;

  Future<List<ConversationSummary>> getConversations() async {
    final rows = await _client.rpc('my_conversations');
    return (rows as List)
        .map((r) => ConversationSummary.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Opens (or reuses) the chat with a mutual follower.
  Future<String> startConversation(String otherId) async =>
      await _client.rpc('start_conversation', params: {'p_other': otherId})
          as String;

  /// Live list, oldest first. RLS limits it to members.
  Stream<List<Message>> watchMessages(String conversationId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map((rows) => rows.map(Message.fromJson).toList());

  Future<void> send(String conversationId, String body) async {
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'body': body.trim(),
    });
  }

  Future<void> markRead(String conversationId) async {
    await _client.rpc(
      'mark_conversation_read',
      params: {'p_conversation': conversationId},
    );
  }

  /// Both follow each other: the precondition for starting a chat.
  Future<bool> isMutual(String me, String other) async {
    final rows = await _client
        .from('follows')
        .select('follower_id')
        .or(
          'and(follower_id.eq.$me,following_id.eq.$other),'
          'and(follower_id.eq.$other,following_id.eq.$me)',
        );
    return (rows as List).length == 2;
  }
}
