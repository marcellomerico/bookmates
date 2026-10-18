import 'dart:async';

import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/auth_fixtures.dart';

void main() {
  test('flag is set by passwordRecovery event and cleared by done()', () async {
    final controller = StreamController<AuthState>();
    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith((ref) => controller.stream)],
    );
    addTearDown(() {
      container.dispose();
      controller.close();
    });
    container.listen(passwordRecoveryProvider, (_, _) {});

    expect(container.read(passwordRecoveryProvider), isFalse);

    controller.add(
      AuthState(AuthChangeEvent.passwordRecovery, testSession('u1')),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(passwordRecoveryProvider), isTrue);

    container.read(passwordRecoveryProvider.notifier).done();
    expect(container.read(passwordRecoveryProvider), isFalse);
  });

  test('sign-out clears the flag', () async {
    final controller = StreamController<AuthState>();
    final container = ProviderContainer(
      overrides: [authStateProvider.overrideWith((ref) => controller.stream)],
    );
    addTearDown(() {
      container.dispose();
      controller.close();
    });
    container.listen(passwordRecoveryProvider, (_, _) {});

    controller.add(
      AuthState(AuthChangeEvent.passwordRecovery, testSession('u1')),
    );
    await Future<void>.delayed(Duration.zero);
    controller.add(signedOut());
    await Future<void>.delayed(Duration.zero);
    expect(container.read(passwordRecoveryProvider), isFalse);
  });
}
