import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads configuration from compile-time `--dart-define` values first,
/// falling back to local `.env` during development.
abstract final class Env {
  static const String _defaultUrl = 'https://dkhazruvustwmudjxiro.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRraGF6cnV2dXN0d211ZGp4aXJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEwODQzNzUsImV4cCI6MjEwNjY2MDM3NX0.oMpNvjQEmopuGL6lu-K5WmI4qy6WOkMoO1udV5l5HL4';

  static const String _urlDefine = String.fromEnvironment('SUPABASE_URL');
  static const String _keyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get supabaseUrl {
    if (_urlDefine.isNotEmpty) return _urlDefine;
    final envVal = _read('SUPABASE_URL', '');
    if (envVal.isNotEmpty) return envVal;
    return _defaultUrl;
  }

  static String get supabaseAnonKey {
    if (_keyDefine.isNotEmpty) return _keyDefine;
    final envVal = _read('SUPABASE_ANON_KEY', '');
    if (envVal.isNotEmpty) return envVal;
    return _defaultAnonKey;
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
