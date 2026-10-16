import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class FollowRepository {
  FollowRepository(this._client);

  final SupabaseClient _client;

  Future<bool> isFollowing({
    required String followerId,
    required String followingId,
  }) async {
    final row = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return row != null;
  }

  Future<void> follow({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) return;
    await _client.from('follows').upsert(
      {'follower_id': followerId, 'following_id': followingId},
      ignoreDuplicates: true,
    );
  }

  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
  }

  Future<List<String>> getFollowingIds(String userId) async {
    final rows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    return (rows as List).map((row) => row['following_id'] as String).toList();
  }

  Future<List<Profile>> getFollowers(String userId) async {
    final rows = await _client
        .from('follows')
        .select('profiles:follower_id(*)')
        .eq('following_id', userId)
        .order('created_at', ascending: false);

    return _mapProfiles(rows as List, 'profiles');
  }

  Future<List<Profile>> getFollowing(String userId) async {
    final rows = await _client
        .from('follows')
        .select('profiles:following_id(*)')
        .eq('follower_id', userId)
        .order('created_at', ascending: false);

    return _mapProfiles(rows as List, 'profiles');
  }

  List<Profile> _mapProfiles(List rows, String key) {
    return rows
        .map((row) {
          final profile = row[key];
          if (profile is Map<String, dynamic>) return Profile.fromJson(profile);
          return null;
        })
        .whereType<Profile>()
        .toList();
  }
}
