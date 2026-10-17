import 'package:bookmates/features/auth/presentation/register_screen.dart';
import 'package:bookmates/features/auth/providers/auth_provider.dart';
import 'package:bookmates/features/books/providers/books_provider.dart';
import 'package:bookmates/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

class _FakeAuth extends AuthRepository {
  _FakeAuth() : super(offlineClient());
  int signUpCalls = 0;

  @override
  Future<SignUpResult> signUp(String email, String password, String username) async {
    signUpCalls++;
    return const SignUpResult(needsEmailConfirmation: true);
  }
}

class _FakeProfiles extends ProfileRepository {
  _FakeProfiles() : super(offlineClient());
  int availabilityCalls = 0;

  @override
  Future<bool> isUsernameAvailable(String username) async {
    availabilityCalls++;
    return true;
  }
}

void main() {
  testWidgets('sign-up is blocked until terms are accepted', (tester) async {
    final auth = _FakeAuth();
    final profiles = _FakeProfiles();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: const MaterialApp(home: RegisterScreen()),
    ));

    await tester.enterText(find.byType(TextField).at(0), 'leser');
    await tester.enterText(find.byType(TextField).at(1), 'a@b.de');
    await tester.enterText(find.byType(TextField).at(2), 'passwort123');

    final submit = find.byType(ElevatedButton);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(
      find.text('Bitte akzeptiere die Nutzungsbedingungen und die Datenschutzerklärung.'),
      findsOneWidget,
    );
    expect(auth.signUpCalls, 0);
    expect(profiles.availabilityCalls, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(submit);
    await tester.pump();
    await tester.pump();

    expect(profiles.availabilityCalls, 1);
    expect(auth.signUpCalls, 1);
  });
}
