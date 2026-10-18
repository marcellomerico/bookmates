import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:booksquad/features/profile/presentation/settings_screen.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';

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
}
