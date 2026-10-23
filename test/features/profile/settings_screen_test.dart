import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/features/profile/presentation/settings_screen.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';
import 'package:booksquad/models/profile.dart';
import 'package:booksquad/repositories/profile_repository.dart';

import '../../helpers/auth_fixtures.dart';

class _FakeProfiles extends ProfileRepository {
  _FakeProfiles() : super(offlineClient());
  final calls = <bool>[];

  @override
  Future<void> setPrivate(String userId, bool isPrivate) async =>
      calls.add(isPrivate);
}

Future<void> _pump(WidgetTester tester, bool admin) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [isAdminProvider.overrideWith((ref) async => admin)],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin sees moderation entry', (tester) async {
    await _pump(tester, true);
    expect(find.text('Meldungen prüfen'), findsOneWidget);
    expect(find.text('Abmelden'), findsOneWidget);
    expect(find.text('Konto löschen'), findsOneWidget);
  });

  testWidgets('non-admin does not see moderation entry', (tester) async {
    await _pump(tester, false);
    expect(find.text('Meldungen prüfen'), findsNothing);
  });

  testWidgets('going public warns about open follow requests', (tester) async {
    final profiles = _FakeProfiles();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWith((ref) async => false),
          currentProfileProvider.overrideWith(
            (ref) async =>
                const Profile(id: 'me', username: 'me', isPrivate: true),
          ),
          followRequestsProvider.overrideWith(
            (ref) async => [const Profile(id: 'x', username: 'x')],
          ),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privates Konto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('automatisch angenommen'), findsOneWidget);

    await tester.tap(find.text('Öffentlich machen'));
    await tester.pumpAndSettle();
    expect(profiles.calls, [false]);
  });
}
