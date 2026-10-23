import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';
import 'features/auth/providers/auth_provider.dart';

/// App-wide messenger so auth link errors can be shown from outside a screen.
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class BooksquadApp extends ConsumerWidget {
  const BooksquadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // An expired or reused e-mail link brings the user back without a session;
    // without this they'd land on the login screen with no explanation.
    ref.listen(authStateProvider, (_, next) {
      final message = next.hasError ? authLinkErrorMessage(next.error!) : null;
      if (message == null) return;
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
    });

    return MaterialApp.router(
      title: 'Booksquad',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
    );
  }
}
