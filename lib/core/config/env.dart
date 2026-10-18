import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static bool _loaded = false;

  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
      _loaded = true;
    } catch (_) {
      _loaded = false;
    }
  }

  static String _read(String key) {
    if (!_loaded || !dotenv.isInitialized) return '';
    return dotenv.env[key] ?? '';
  }

  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');
  static String get googleWebClientId => _read('GOOGLE_WEB_CLIENT_ID');
  static String get googleIosClientId => _read('GOOGLE_IOS_CLIENT_ID');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;

  static bool get isGoogleConfigured => googleWebClientId.isNotEmpty;
}
