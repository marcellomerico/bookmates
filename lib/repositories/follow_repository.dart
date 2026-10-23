import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

enum FollowState { none, requested, following }

class FollowRepository {
  FollowRepository(this._client);

  final SupabaseClient _client;

  Future<FollowState> followState({
    required String followerId,
    required String followingId,
  }) async {
    final row = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    if (row != null) return FollowState.following;
    final request = await _client
        .from('follow_requests')
        .select('requester_id')
        .eq('requester_id', followerId)
        .eq('target_id', followingId)
        .maybeSingle();
    return request != null ? FollowState.requested : FollowState.none;
  }

  /// Follows a public account or sends a request to a private one.
  Future<FollowState> follow({
    required String followerId,
    required String followingId,
  }) async {
    if (followerId == followingId) return FollowState.none;
    final result = await _client.rpc(
      'follow_user',
      params: {'p_target': followingId},
    );
    return result == 'requested'
        ? FollowState.requested
        : FollowState.following;
  }

  /// Unfollows, or withdraws a pending request.
  Future<void> unfollow({
    required String followerId,
    required String followingId,
  }) async {
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', followingId);
    await _client
        .from('follow_requests')
        .delete()
        .eq('requester_id', followerId)
        .eq('target_id', followingId);
  }

  Future<List<Profile>> getFollowRequests(String userId) async {
    final rows = await _client
        .from('follow_requests')
        .select('profiles:requester_id(*)')
        .eq('target_id', userId)
        .order('created_at', ascending: false);
    return _mapProfiles(rows as List, 'profiles');
  }

  Future<void> respondToRequest(String requesterId, {required bool accept}) =>
      _client.rpc(
        'respond_follow_request',
        params: {'p_requester': requesterId, 'p_accept': accept},
      );

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
