import 'package:bookmates/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:bookmates/features/social/providers/social_providers.dart';
import 'package:bookmates/models/moderation_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(List<ModerationReport> reports) => ProviderScope(
  overrides: [openReportsProvider.overrideWith((ref) async => reports)],
  child: const MaterialApp(home: ModerationQueueScreen()),
);

void main() {
  testWidgets('shows content and user-only reports with matching actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        ModerationReport(
          reportId: 'r1',
          reportedAt: DateTime.now(),
          reason: 'Spam im Beitrag',
          reporterUsername: 'anna',
          targetUsername: 'bob',
          targetPostId: 'p1',
          content: 'Kaufe jetzt!',
        ),
        ModerationReport(
          reportId: 'r2',
          reportedAt: DateTime.now(),
          reason: 'Beleidigendes Profil',
          reporterUsername: 'anna',
          targetUserId: 'u1',
          targetUsername: 'carl',
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spam im Beitrag'), findsOneWidget);
    expect(find.text('Beleidigendes Profil'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);
    expect(find.text('Erledigt'), findsOneWidget);
    expect(find.text('Profil gemeldet'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Keine offenen Meldungen'), findsOneWidget);
  });
}
