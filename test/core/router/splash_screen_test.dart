import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bookmates/core/router/splash_screen.dart';
import 'package:bookmates/features/auth/providers/auth_provider.dart';
import 'package:bookmates/models/profile.dart';

Widget _app(Future<Profile?> Function() future) => ProviderScope(
      overrides: [currentProfileProvider.overrideWith((ref) => future())],
      child: const MaterialApp(home: SplashScreen()),
    );

void main() {
  testWidgets('shows retry when profile fails', (tester) async {
    await tester.pumpWidget(_app(() => Future<Profile?>.error(Exception('net'))));
    await tester.pump();
    await tester.pump();
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets('shows spinner while loading', (tester) async {
    await tester.pumpWidget(_app(() => Completer<Profile?>().future));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
