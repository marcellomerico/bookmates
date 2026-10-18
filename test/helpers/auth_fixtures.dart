import 'package:supabase_flutter/supabase_flutter.dart';

User testUser(String id) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

Session testSession(String userId) => Session(
  accessToken: 'test-access-token',
  tokenType: 'bearer',
  user: testUser(userId),
);

AuthState signedIn(String userId) =>
    AuthState(AuthChangeEvent.signedIn, testSession(userId));

AuthState signedOut() => AuthState(AuthChangeEvent.signedOut, null);

SupabaseClient offlineClient() => SupabaseClient(
  'http://localhost:54321',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);
