import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('expired or used link (error params from the redirect URL)', () {
    const e = AuthException(
      'Email link is invalid or has expired',
      statusCode: 'otp_expired',
      code: 'access_denied',
    );
    expect(authLinkErrorMessage(e), contains('abgelaufen'));
  });

  test('link opened on another device (missing PKCE verifier)', () {
    const e = AuthException(
      'Code verifier could not be found in local storage.',
    );
    expect(authLinkErrorMessage(e), contains('Gerät'));
  });

  test('other auth errors are not link errors', () {
    expect(
      authLinkErrorMessage(const AuthException('Invalid Refresh Token')),
      isNull,
    );
    expect(authLinkErrorMessage(StateError('x')), isNull);
  });
}
