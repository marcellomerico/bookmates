import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group.dart';

class GroupRepository {
  GroupRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, profiles!creator_id(*), group_members(user_id)';

  Future<List<BookGroup>> listGroups({
    String? currentUserId,
    String? query,
  }) async {
    var request = _client
        .from('groups')
        .select(_select)
        .order('created_at', ascending: false);

    final rows = await request;
    var groups = (rows as List)
        .map(
          (row) => BookGroup.fromJson(
            row as Map<String, dynamic>,
            currentUserId: currentUserId,
          ),
        )
        .where((g) =>
            !g.isPrivate ||
            g.isMember ||
            (currentUserId != null && g.creatorId == currentUserId))
        .toList();

    final trimmed = query?.trim().toLowerCase();
    if (trimmed != null && trimmed.isNotEmpty) {
      groups = groups
          .where(
            (g) =>
                g.name.toLowerCase().contains(trimmed) ||
                (g.description?.toLowerCase().contains(trimmed) ?? false),
          )
          .toList();
    }

    return groups;
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

    await _client.from('group_members').upsert({
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
    await _client.from('group_members').upsert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'member',
    });
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
