import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationRepository {
  ModerationRepository(this._client);

  final SupabaseClient _client;

  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    await _client.from('blocks').upsert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    });
  }

  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async {
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId);
  }

  Future<bool> isBlocked({
    required String blockerId,
    required String blockedId,
  }) async {
    final row = await _client
        .from('blocks')
        .select('blocker_id')
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId)
        .maybeSingle();
    return row != null;
  }

  Future<List<String>> getBlockedUserIds(String userId) async {
    final rows = await _client.from('blocks').select('blocked_id').eq('blocker_id', userId);
    return (rows as List).map((row) => row['blocked_id'] as String).toList();
  }

  Future<void> reportContent({
    required String reporterId,
    required String reason,
    String? reportedUserId,
    String? postId,
    String? commentId,
  }) async {
    await _client.from('reports').insert({
      'reporter_id': reporterId,
      'reason': reason.trim(),
      'reported_user_id': ?reportedUserId,
      'post_id': ?postId,
      'comment_id': ?commentId,
    });
  }
}
