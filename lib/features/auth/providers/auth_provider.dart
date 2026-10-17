import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/app_config.dart';
import '../../../models/profile.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  // Recompute only when the signed-in user changes, not on every token refresh.
  // hasValue also re-runs on the first event so the persisted-session fallback is dropped.
  ref.watch(
    authStateProvider.select(
      (s) => (s.hasValue, s.valueOrNull?.session?.user.id),
    ),
  );
  final auth = ref.read(authStateProvider);
  if (auth.hasValue) return auth.value!.session?.user;
  // Before the first auth event: fall back to the persisted session.
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

/// True after the user opened a password-reset link until a new password is set.
class PasswordRecovery extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authStateProvider, (_, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery) state = true;
      if (event == AuthChangeEvent.signedOut) state = false;
    });
    return false;
  }

  void done() => state = false;
}

final passwordRecoveryProvider = NotifierProvider<PasswordRecovery, bool>(
  PasswordRecovery.new,
);

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

/// Auth error raised by Bookmates itself; its message is user-facing German text.
class AppAuthException extends AuthException {
  const AppAuthException(super.message);
}

bool isRateLimit(Object e) =>
    e is PostgrestException && e.message == 'rate_limit';

String authErrorMessage(Object error) {
  if (error is AuthException) {
    if (error is AppAuthException) return error.message;
    final message = error.message.toLowerCase();
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return 'E-Mail oder Passwort falsch.';
    }
    if (message.contains('user already registered')) {
      return 'Diese E-Mail ist bereits registriert.';
    }
    if (message.contains('email not confirmed')) {
      return 'Bitte bestätige zuerst deine E-Mail-Adresse.';
    }
    if (error is AuthWeakPasswordException || error.code == 'weak_password') {
      return 'Das Passwort ist zu schwach. Bitte wähle ein längeres Passwort.';
    }
    if (error.statusCode == '429' ||
        error.code == 'over_email_send_rate_limit' ||
        error.code == 'over_request_rate_limit') {
      return 'Zu viele Versuche. Bitte später erneut versuchen.';
    }
    if (error.code == 'email_address_invalid') {
      return 'Bitte gib eine gültige E-Mail-Adresse ein.';
    }
    if (error is AuthRetryableFetchException && error.statusCode == null) {
      return 'Keine Verbindung. Bitte prüfe deine Internetverbindung.';
    }
    debugPrint('Auth error: ${error.message}');
    return 'Ein Fehler ist aufgetreten. Bitte erneut versuchen.';
  }
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    if (message.contains('not authenticated')) {
      return 'Nicht angemeldet.';
    }
    if (error.message == 'rate_limit') {
      return 'Zu viele Aktionen in kurzer Zeit. Bitte warte einen Moment.';
    }
    debugPrint('Auth error: ${error.message}');
    return 'Ein Fehler ist aufgetreten. Bitte erneut versuchen.';
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

  Future<SignUpResult> signUp(
    String email,
    String password,
    String username,
  ) async {
    final trimmedEmail = email.trim();
    final trimmedUsername = username.trim();

    if (trimmedUsername.isEmpty) {
      throw const AppAuthException('Bitte gib einen Benutzernamen ein.');
    }

    final response = await _client.auth.signUp(
      email: trimmedEmail,
      password: password,
      emailRedirectTo: AppConfig.authRedirectUrl,
      data: {'username': trimmedUsername, 'display_name': trimmedUsername},
    );

    final user = response.user;
    if (user == null) {
      throw const AppAuthException(
        'Registrierung fehlgeschlagen. Ist die E-Mail bereits registriert?',
      );
    }

    return SignUpResult(needsEmailConfirmation: response.session == null);
  }

  Future<void> signInWithGoogle() async {
    final googleSignIn = _googleSignIn;
    if (googleSignIn == null) {
      throw const AppAuthException('Google Sign-In ist nicht konfiguriert.');
    }

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AppAuthException('Anmeldung abgebrochen.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw const AppAuthException(
        'Anmeldung fehlgeschlagen. Bitte erneut versuchen.',
      );
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
      throw const AppAuthException(
        'Anmeldung fehlgeschlagen. Bitte erneut versuchen.',
      );
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
      try {
        await _client
            .from('profiles')
            .update({
              'display_name': displayName.length > AppLimits.displayName
                  ? displayName.substring(0, AppLimits.displayName)
                  : displayName,
            })
            .eq('id', user.id);
      } catch (e) {
        debugPrint('Apple display name update failed: $e');
      }
    }
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.authRedirectUrl,
    );
  }

  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> deleteAccount() async {
    if (_client.auth.currentUser == null) {
      throw const AppAuthException('Nicht angemeldet.');
    }

    try {
      await _client.functions.invoke('delete-account', method: HttpMethod.post);
    } on FunctionException catch (e) {
      debugPrint('delete-account failed: ${e.status} ${e.details}');
      throw const AppAuthException(
        'Konto konnte nicht gelöscht werden. Bitte später erneut versuchen.',
      );
    }
    try {
      await _googleSignIn?.signOut();
    } finally {
      // The server-side user is gone; always clear the local session.
      await _client.auth.signOut(scope: SignOutScope.local);
    }
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
