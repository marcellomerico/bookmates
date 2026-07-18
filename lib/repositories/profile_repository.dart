import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

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
  }) async {
    await _client.from('profiles').update({
      'display_name': displayName.trim(),
      'bio': bio.trim(),
    }).eq('id', userId);

    if (genres.isEmpty) return;

    final genreRows = await _client.from('genres').select('id, name');
    final genreMap = {
      for (final row in genreRows as List)
        row['name'] as String: row['id'] as String,
    };

    await _client.from('user_genres').delete().eq('user_id', userId);
    await _client.from('user_genres').insert(
      genres
          .where(genreMap.containsKey)
          .map((genre) => {
                'user_id': userId,
                'genre_id': genreMap[genre],
              })
          .toList(),
    );
  }

  Future<Profile?> getProfile(String userId) async {
    final data = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }
}
