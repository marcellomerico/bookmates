import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/profile.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final data = await ref.watch(supabaseClientProvider).from('profiles').select().eq('id', user.id).maybeSingle();
  if (data == null) return null;
  return Profile.fromJson(data);
});

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password, String username) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final user = response.user;
    if (user == null) return;

    await _client.from('profiles').upsert({
      'id': user.id,
      'username': username,
      'display_name': username,
      'onboarding_completed': false,
    });
  }

  Future<void> signOut() => _client.auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
