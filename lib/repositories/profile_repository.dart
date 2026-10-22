import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/validators.dart';
import '../models/profile.dart';
import '../models/profile_stats.dart';
import '../models/shelf_decor.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<List<String>> getUserGenreNames(String userId) async {
    final rows = await _client
        .from('user_genres')
        .select('genres(name)')
        .eq('user_id', userId);

    return (rows as List)
        .map((row) => (row['genres'] as Map<String, dynamic>)['name'] as String)
        .toList();
  }

  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
    required Set<String> genres,
    String? username,
  }) async {
    await _client
        .from('profiles')
        .update({
          'display_name': displayName.trim(),
          'bio': bio.trim(),
          if (username != null) 'username': username.trim().toLowerCase(),
        })
        .eq('id', userId);

    if (genres.isEmpty) {
      await _client.from('user_genres').delete().eq('user_id', userId);
      return;
    }

    final genreRows = await _client.from('genres').select('id, name');
    final genreMap = {
      for (final row in genreRows as List)
        row['name'] as String: row['id'] as String,
    };

    await _client.from('user_genres').delete().eq('user_id', userId);
    await _client
        .from('user_genres')
        .insert(
          genres
              .where(genreMap.containsKey)
              .map((genre) => {'user_id': userId, 'genre_id': genreMap[genre]})
              .toList(),
        );
  }

  Future<void> updateShelfDecor(String userId, List<DecorPiece> decor) async {
    await _client
        .from('profiles')
        .update({'shelf_decor': [for (final p in decor) p.toJson()]})
        .eq('id', userId);
  }

  Future<bool> isUsernameAvailable(String username) async {
    final trimmed = username.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    final result = await _client.rpc(
      'username_available',
      params: {'p_username': trimmed},
    );
    return result == true;
  }

  Future<Profile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ext = contentType.contains('png') ? 'png' : 'jpg';
    final path = '$userId/avatar.$ext';

    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    final busted = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    await _client
        .from('profiles')
        .update({'avatar_url': busted})
        .eq('id', userId);
    return busted;
  }

  Future<ProfileStats> getStats(String userId) async {
    final counts = await Future.wait([
      _client
          .from('posts')
          .select('id')
          .eq('author_id', userId)
          .count(CountOption.exact),
      _client
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId)
          .count(CountOption.exact),
      _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId)
          .count(CountOption.exact),
    ]);

    return ProfileStats(
      postCount: counts[0].count,
      followerCount: counts[1].count,
      followingCount: counts[2].count,
    );
  }

  Future<List<Profile>> searchProfiles(
    String query, {
    String? excludeUserId,
    int limit = 20,
  }) async {
    final trimmed = sanitizeSearchTerm(query);
    if (trimmed.isEmpty) return [];

    var request = _client
        .from('profiles')
        .select()
        .or('username.ilike.%$trimmed%,display_name.ilike.%$trimmed%')
        .limit(limit);

    final rows = await request;
    return (rows as List)
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .where((p) => p.id != excludeUserId)
        .toList();
  }

  Future<List<Profile>> recommendByGenres(
    String userId, {
    int limit = 10,
  }) async {
    final myGenres = await getUserGenreNames(userId);
    if (myGenres.isEmpty) {
      final rows = await _client
          .from('profiles')
          .select()
          .neq('id', userId)
          .limit(limit);
      return (rows as List)
          .map((row) => Profile.fromJson(row as Map<String, dynamic>))
          .toList();
    }

    final genreRows = await _client.from('genres').select('id, name');
    final genreIds = (genreRows as List)
        .where((row) => myGenres.contains(row['name']))
        .map((row) => row['id'] as String)
        .toList();

    if (genreIds.isEmpty) return [];

    final overlaps = await _client
        .from('user_genres')
        .select('user_id')
        .inFilter('genre_id', genreIds)
        .neq('user_id', userId);

    final counts = <String, int>{};
    for (final row in overlaps as List) {
      final id = row['user_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }

    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topIds = ranked.take(limit).map((e) => e.key).toList();
    if (topIds.isEmpty) return [];

    final profiles = await _client
        .from('profiles')
        .select()
        .inFilter('id', topIds);
    final byId = {
      for (final row in profiles as List)
        (row as Map<String, dynamic>)['id'] as String: Profile.fromJson(row),
    };
    return topIds.map((id) => byId[id]).whereType<Profile>().toList();
  }
}
