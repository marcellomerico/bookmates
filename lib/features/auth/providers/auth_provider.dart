import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
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

  final data = await ref
      .watch(supabaseClientProvider)
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();
  if (data == null) return null;
  return Profile.fromJson(data);
});

String authErrorMessage(Object error) {
  if (error is AuthException) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return 'E-Mail oder Passwort falsch.';
    }
    if (message.contains('user already registered')) {
      return 'Diese E-Mail ist bereits registriert. '
          'Falls du den Account gelöscht hast, prüfe in Supabase ob die '
          'Löschung vollständig war (siehe TESTING.md → Troubleshooting).';
    }
    if (message.contains('email not confirmed')) {
      return 'Bitte bestätige zuerst deine E-Mail-Adresse.';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    if (message.contains('not authenticated')) {
      return 'Nicht angemeldet.';
    }
    if (message.contains('could not be deleted') ||
        message.contains('account could not')) {
      return 'Account konnte nicht vollständig gelöscht werden. '
          'Bitte Migration 4 in Supabase ausführen (TESTING.md Teil A.5).';
    }
    return error.message;
  }
  if (error is SignInWithAppleAuthorizationException &&
      error.code == AuthorizationErrorCode.canceled) {
    return 'Anmeldung abgebrochen.';
  }
  return 'Ein Fehler ist aufgetreten. Bitte erneut versuchen.';
}

/// Result of email/password registration.
class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});

  /// True when Supabase requires e-mail confirmation before first login.
  final bool needsEmailConfirmation;
}

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoogleSignIn? get _googleSignIn {
    if (!Env.isGoogleConfigured) return null;
    return GoogleSignIn(
      clientId:
          defaultTargetPlatform == TargetPlatform.iOS &&
              Env.googleIosClientId.isNotEmpty
          ? Env.googleIosClientId
          : null,
      serverClientId: Env.googleWebClientId,
      scopes: const ['email', 'profile'],
    );
  }

  Future<void> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<SignUpResult> signUp(String email, String password, String username) async {
    final trimmedEmail = email.trim();
    final trimmedUsername = username.trim();

    if (trimmedUsername.isEmpty) {
      throw const AuthException('Bitte gib einen Benutzernamen ein.');
    }

    final response = await _client.auth.signUp(
      email: trimmedEmail,
      password: password,
      data: {'username': trimmedUsername, 'display_name': trimmedUsername},
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException(
        'Registrierung fehlgeschlagen. Ist die E-Mail bereits registriert?',
      );
    }

    // Trigger may have created a profile — update with chosen username.
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'username': trimmedUsername,
        'display_name': trimmedUsername,
        'onboarding_completed': false,
      });
    } on PostgrestException catch (e) {
      // Username taken by another account — remove orphan auth user if possible.
      if (e.code == '23505') {
        throw const AuthException(
          'Dieser Benutzername ist bereits vergeben. Bitte wähle einen anderen.',
        );
      }
      rethrow;
    }

    return SignUpResult(needsEmailConfirmation: response.session == null);
  }

  Future<void> signInWithGoogle() async {
    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      throw const AuthException('Google Sign-In ist nicht konfiguriert.');
    }

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Anmeldung abgebrochen.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw const AuthException('Google ID Token fehlt.');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  Future<void> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple ID Token fehlt.');
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final user = _client.auth.currentUser;
    if (user == null) return;

    final displayName = [
      credential.givenName,
      credential.familyName,
    ].where((part) => part != null && part.isNotEmpty).join(' ');

    if (displayName.isNotEmpty) {
      await _client
          .from('profiles')
          .update({'display_name': displayName})
          .eq('id', user.id);
    }
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> deleteAccount() async {
    if (_client.auth.currentUser == null) {
      throw const AuthException('Nicht angemeldet.');
    }

    try {
      await _client.rpc('delete_own_account');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || (e.message).contains('delete_own_account')) {
        throw const AuthException(
          'Account-Löschung ist nicht eingerichtet. Bitte Migration 3+4 in Supabase ausführen.',
        );
      }
      rethrow;
    }

    await _googleSignIn?.signOut();
    await _client.auth.signOut(scope: SignOutScope.global);
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});
