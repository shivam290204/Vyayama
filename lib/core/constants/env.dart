import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads configuration from compile-time `--dart-define` values first,
/// falling back to local `.env` during development.
abstract final class Env {
  static const String _urlDefine = String.fromEnvironment('SUPABASE_URL');
  static const String _keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl {
    if (_urlDefine.isNotEmpty) return _urlDefine;
    final envVal = _read('SUPABASE_URL', '');
    if (envVal.isNotEmpty) return envVal;
    return '';
  }

  static String get supabaseAnonKey {
    if (_keyDefine.isNotEmpty) return _keyDefine;
    final envVal = _read('SUPABASE_ANON_KEY', '');
    if (envVal.isNotEmpty) return envVal;
    return '';
  }

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
