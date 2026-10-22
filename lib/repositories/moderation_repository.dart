import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/providers/auth_provider.dart' show AppAuthException;
import '../models/moderation_report.dart';
import '../models/verification.dart';

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
    final rows = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', userId);
    return (rows as List).map((row) => row['blocked_id'] as String).toList();
  }

  Future<void> reportContent({
    required String reporterId,
    required String reason,
    String? reportedUserId,
    String? postId,
    String? commentId,
  }) async {
    try {
      await _client.from('reports').insert({
        'reporter_id': reporterId,
        'reason': reason.trim(),
        'reported_user_id': ?reportedUserId,
        'post_id': ?postId,
        'comment_id': ?commentId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AppAuthException('Du hast das bereits gemeldet.');
      }
      rethrow;
    }
  }

  Future<bool> isAdmin() async {
    final result = await _client.rpc('am_i_admin');
    return result == true;
  }

  Future<List<ModerationReport>> openReports() async {
    final rows = await _client.rpc('admin_open_reports');
    return (rows as List)
        .map((row) => ModerationReport.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// [action] is 'dismiss', 'hide' or 'delete'.
  Future<void> resolveReport(String reportId, String action) async {
    await _client.rpc(
      'admin_resolve_report',
      params: {'p_report_id': reportId, 'p_action': action},
    );
  }

  /// The caller's newest request, open or resolved, or null.
  Future<VerificationRequest?> myVerificationRequest() async {
    final row = await _client
        .from('verification_requests')
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : VerificationRequest.fromJson(row);
  }

  Future<void> requestVerification({
    required VerificationKind kind,
    required String link,
    String? note,
  }) async {
    await _client.from('verification_requests').insert({
      'kind': kind.name,
      'link': link,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<List<VerificationRequest>> openVerifications() async {
    final rows = await _client.rpc('admin_open_verifications');
    return (rows as List)
        .map((r) => VerificationRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> resolveVerification(String requestId, {required bool approve}) =>
      _client.rpc(
        'admin_resolve_verification',
        params: {'p_request_id': requestId, 'p_approve': approve},
      );

  Future<void> revokeVerification(String userId) =>
      _client.rpc('admin_revoke_verification', params: {'p_user_id': userId});
}
