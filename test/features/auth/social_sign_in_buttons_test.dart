import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmates/features/auth/presentation/social_sign_in_buttons.dart';

void main() {
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
