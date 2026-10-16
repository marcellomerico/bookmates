import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmates/core/config/setup_screen.dart';

void main() {
  testWidgets('Setup screen renders when env missing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SetupScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Bookmates Setup'), findsOneWidget);
  });
}
