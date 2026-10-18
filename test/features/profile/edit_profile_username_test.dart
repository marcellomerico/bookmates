import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/features/profile/presentation/edit_profile_screen.dart';
import 'package:booksquad/models/profile.dart';
import 'package:booksquad/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/auth_fixtures.dart';

class _FakeProfiles extends ProfileRepository {
  _FakeProfiles() : super(offlineClient());

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      username != 'taken';
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith(
          (ref) async => const Profile(
            id: 'me',
            username: 'usera_6a1ee2',
            displayName: 'Marcello',
          ),
        ),
        userGenresProvider.overrideWith((ref) async => const []),
        profileRepositoryProvider.overrideWithValue(_FakeProfiles()),
      ],
      child: const MaterialApp(home: EditProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _usernameField => find.widgetWithText(TextField, 'Benutzername');

void main() {
  testWidgets('shows the current username', (tester) async {
    await _pump(tester);
    expect(find.text('usera_6a1ee2'), findsOneWidget);
  });

  testWidgets('free name is reported as available, input is lowercased', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(_usernameField, 'Marcello');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('marcello'), findsOneWidget);
    expect(find.text('Verfügbar'), findsOneWidget);
  });

  testWidgets('taken name shows an error', (tester) async {
    await _pump(tester);
    await tester.enterText(_usernameField, 'taken');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(
      find.text('Dieser Benutzername ist schon vergeben.'),
      findsOneWidget,
    );
  });

  testWidgets('too short name shows the format rule without a lookup', (
    tester,
  ) async {
    await _pump(tester);
    await tester.enterText(_usernameField, 'ab');
    await tester.pump();
    expect(find.textContaining('3–24 Zeichen'), findsOneWidget);
  });
}
