import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const generic = 'Ein Fehler ist aufgetreten. Bitte erneut versuchen.';

  test('AppAuthException keeps its German message', () {
    expect(
      authErrorMessage(const AppAuthException('Anmeldung abgebrochen.')),
      'Anmeldung abgebrochen.',
    );
  });
  test('plain AuthException without statusCode and raw text is generic', () {
    expect(
      authErrorMessage(const AuthException('database error saving user')),
      generic,
    );
  });
  test('server AuthException with unknown text is generic', () {
    expect(
      authErrorMessage(const AuthException('some raw', statusCode: '500')),
      generic,
    );
  });
  test('invalid credentials maps to German message', () {
    expect(
      authErrorMessage(
        const AuthException('Invalid login credentials', statusCode: '400'),
      ),
      'E-Mail oder Passwort falsch.',
    );
  });
  test('weak password', () {
    expect(
      authErrorMessage(
        AuthWeakPasswordException(
          message: 'Password should be at least 6 characters',
          statusCode: '422',
          reasons: const ['length'],
        ),
      ),
      'Das Passwort ist zu schwach. Bitte wähle ein längeres Passwort.',
    );
  });
  test('network failure', () {
    expect(
      authErrorMessage(
        AuthRetryableFetchException(message: 'SocketException: failed'),
      ),
      'Keine Verbindung. Bitte prüfe deine Internetverbindung.',
    );
  });
  test('rate limit', () {
    expect(
      authErrorMessage(const AuthException('x', statusCode: '429')),
      'Zu viele Versuche. Bitte später erneut versuchen.',
    );
  });
  test('PostgrestException is generic', () {
    expect(authErrorMessage(const PostgrestException(message: 'raw')), generic);
  });
  test('rate_limit PostgrestException maps to German text', () {
    expect(
      authErrorMessage(PostgrestException(message: 'rate_limit')),
      'Zu viele Aktionen in kurzer Zeit. Bitte warte einen Moment.',
    );
    expect(isRateLimit(PostgrestException(message: 'rate_limit')), isTrue);
    expect(isRateLimit(PostgrestException(message: 'other')), isFalse);
  });
}
