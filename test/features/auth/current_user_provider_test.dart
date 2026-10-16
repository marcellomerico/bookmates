import 'dart:async';

import 'package:bookmates/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_fixtures.dart';

void main() {
  test('currentUserProvider follows sign-in, sign-out and account switch', () async {
    final controller = StreamController<AuthState>();
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(offlineClient()),
        authStateProvider.overrideWith((ref) => controller.stream),
      ],
    );
    addTearDown(() {
      container.dispose();
      controller.close();
    });
    container.listen(currentUserProvider, (_, _) {});

    expect(container.read(currentUserProvider), isNull);

    controller.add(signedIn('user-a'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentUserProvider)?.id, 'user-a');

    controller.add(signedOut());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentUserProvider), isNull);

    controller.add(signedIn('user-b'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentUserProvider)?.id, 'user-b');
  });
}
