import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:booksquad/core/widgets/state_views.dart';

void main() {
  testWidgets('EmptyState renders title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.book, title: 'Titel', message: 'Nachricht'),
        ),
      ),
    );
    expect(find.text('Titel'), findsOneWidget);
    expect(find.text('Nachricht'), findsOneWidget);
  });

  testWidgets('ErrorState retry calls callback', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ErrorState(onRetry: () => calls++))),
    );
    expect(find.text('Das hat nicht geklappt.'), findsOneWidget);
    await tester.tap(find.text('Erneut versuchen'));
    expect(calls, 1);
  });
}
