import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/config/setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/fonts/OFL-SourceSerif4.txt',
    );
    yield LicenseEntryWithLineBreaks(['Source Serif 4'], license);
  });
  await Env.load();
  await initializeDateFormatting('de');

  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  runApp(
    ProviderScope(
      child: Env.isConfigured ? const BooksquadApp() : const _SetupApp(),
    ),
  );
}

class _SetupApp extends StatelessWidget {
  const _SetupApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Booksquad Setup',
      debugShowCheckedModeBanner: false,
      home: const SetupScreen(),
    );
  }
}
