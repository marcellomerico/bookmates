import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bookmates/app.dart';

void main() {
  testWidgets('Bookmates app renders login screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BookmatesApp()));
    await tester.pumpAndSettle();

    expect(find.text('Bookmates'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
  });
}
