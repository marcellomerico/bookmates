import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bookmates/app.dart';
import 'package:bookmates/core/config/env.dart';
import 'package:bookmates/core/config/setup_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Env.load();
    if (Env.isConfigured) {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
    }
  });

  testWidgets('Bookmates renders initial screen', (tester) async {
    if (!Env.isConfigured) {
      await tester.pumpWidget(const MaterialApp(home: SetupScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Bookmates Setup'), findsOneWidget);
      return;
    }

    await tester.pumpWidget(const ProviderScope(child: BookmatesApp()));
    await tester.pumpAndSettle();

    expect(find.text('Bookmates'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
  });
}
