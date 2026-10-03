import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads configuration from `.env`, falling back to `--dart-define` values.
abstract final class Env {
  static const String _urlDefine = String.fromEnvironment('SUPABASE_URL');
  static const String _keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl => _read('SUPABASE_URL', _urlDefine);
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY', _keyDefine);

  /// True when real (non-placeholder) Supabase values are available.
  static bool get isSupabaseConfigured {
    final url = supabaseUrl;
    final key = supabaseAnonKey;
    return url.startsWith('http') && key.isNotEmpty && !key.startsWith('your-');
  }

  static String _read(String name, String fallback) {
    if (!dotenv.isInitialized) return fallback;
    final value = dotenv.env[name];
    return (value == null || value.isEmpty) ? fallback : value;
  }
}
