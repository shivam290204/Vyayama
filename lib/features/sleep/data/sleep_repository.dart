import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';

/// Storage for sleep settings.
///
/// Antigravity: save work times to `profiles.work_start` / `work_end` and
/// the remaining values to `shared_preferences`.
abstract class SleepRepository {
  /// Loads the saved settings.
  Future<SleepSettings> loadSettings();

  /// Saves the settings.
  Future<void> saveSettings(SleepSettings settings);
}
