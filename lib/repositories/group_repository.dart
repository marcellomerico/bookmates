import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/validators.dart';
import '../models/group.dart';

class GroupRepository {
  GroupRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, profiles!creator_id(*), group_members(user_id)';
  static const _listSelect = '*, profiles!creator_id(*), group_members(count)';

  Future<List<BookGroup>> listGroups({
    String? currentUserId,
    String? query,
  }) async {
    var request = _client.from('groups').select(_listSelect);
    final term = sanitizeSearchTerm(query ?? '');
    if (term.isNotEmpty) request = request.ilike('name', '%$term%');

    // RLS already hides private groups the user may not see.
    final results = await Future.wait([
      request.order('created_at', ascending: false).limit(50),
      if (currentUserId != null)
        _client.from('group_members').select('group_id').eq('user_id', currentUserId),
    ]);
    final memberOf = currentUserId == null
        ? <String>{}
        : {for (final r in results[1] as List) r['group_id'] as String};

    return (results[0] as List)
        .map((row) => BookGroup.fromJson(row as Map<String, dynamic>))
        .map((g) => g.copyWith(isMember: memberOf.contains(g.id)))
        .toList();
  }

  Future<BookGroup?> getGroup(String groupId, {String? currentUserId}) async {
    final row = await _client
        .from('groups')
        .select(_select)
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) return null;
    return BookGroup.fromJson(row, currentUserId: currentUserId);
  }

  Future<BookGroup> createGroup({
    required String creatorId,
    required String name,
    String? description,
    bool isPrivate = false,
  }) async {
    final inserted = await _client
        .from('groups')
        .insert({
          'creator_id': creatorId,
          'name': name.trim(),
          'is_private': isPrivate,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        })
        .select(_select)
        .single();

    await _client.from('group_members').insert({
      'group_id': inserted['id'],
      'user_id': creatorId,
      'role': 'admin',
    });

    return getGroup(
      inserted['id'] as String,
      currentUserId: creatorId,
    ).then((g) => g!);
  }

  Future<void> joinGroup({
    required String groupId,
    required String userId,
  }) async {
    // ON CONFLICT DO NOTHING: RLS has no UPDATE policy on memberships.
    await _client.from('group_members').upsert(
      {'group_id': groupId, 'user_id': userId, 'role': 'member'},
      ignoreDuplicates: true,
    );
  }

  /// Joins a (private) group by invite code; returns the group id.
  Future<String> joinWithCode(String code) async {
    final result = await _client.rpc(
      'join_group_with_code',
      params: {'code': code},
    );
    return result as String;
  }

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }
}
