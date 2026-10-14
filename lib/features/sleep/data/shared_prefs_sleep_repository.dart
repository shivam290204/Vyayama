import 'dart:convert';
import 'package:fitbuddy/features/sleep/data/sleep_repository.dart';
import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences-backed [SleepRepository] for persisting sleep & alarm settings.
class SharedPrefsSleepRepository implements SleepRepository {
  SharedPrefsSleepRepository(this._prefs);

  final SharedPreferences _prefs;
  static const String _storageKey = 'vyayama_sleep_settings_v1';

  @override
  Future<SleepSettings> loadSettings() async {
    try {
      final raw = _prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> json =
            jsonDecode(raw) as Map<String, dynamic>;
        return SleepSettings.fromJson(json);
      }
    } catch (_) {}
    return const SleepSettings();
  }

  @override
  Future<void> saveSettings(SleepSettings settings) async {
    try {
      final raw = jsonEncode(settings.toJson());
      await _prefs.setString(_storageKey, raw);
    } catch (_) {}
  }
}
