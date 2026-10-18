import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booksquad/features/auth/presentation/social_sign_in_buttons.dart';

void main() {
  test('terms notice names exactly the shown providers', () {
    expect(
      socialTermsNoticePrefix(apple: true, google: false),
      'Mit der Anmeldung über Apple akzeptierst du unsere ',
    );
    expect(
      socialTermsNoticePrefix(apple: false, google: true),
      'Mit der Anmeldung über Google akzeptierst du unsere ',
    );
    expect(
      socialTermsNoticePrefix(apple: true, google: true),
      'Mit der Anmeldung über Apple oder Google akzeptierst du unsere ',
    );
  });

  testWidgets('shows nothing without Google config on non-iOS', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SocialSignInButtons())),
      ),
    );
    expect(find.text('Mit Google anmelden'), findsNothing);
    expect(find.textContaining('GOOGLE_WEB_CLIENT_ID'), findsNothing);
    expect(find.text('oder'), findsNothing);
  });
}
