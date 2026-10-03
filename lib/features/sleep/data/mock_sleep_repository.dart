import 'package:fitbuddy/features/sleep/data/sleep_repository.dart';
import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';

/// In-memory [SleepRepository].
class MockSleepRepository implements SleepRepository {
  SleepSettings _settings = const SleepSettings();

  @override
  Future<SleepSettings> loadSettings() async => _settings;

  @override
  Future<void> saveSettings(SleepSettings settings) async {
    _settings = settings;
  }
}
