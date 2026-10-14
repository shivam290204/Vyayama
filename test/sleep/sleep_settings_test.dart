import 'package:fitbuddy/features/sleep/data/shared_prefs_sleep_repository.dart';
import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SleepSettings model', () {
    test('defaults are reasonable', () {
      const settings = SleepSettings();
      expect(settings.workStart, isNull);
      expect(settings.workEnd, isNull);
      expect(settings.sleepMinutes, isNull);
      expect(settings.customBedtime, isNull);
      expect(settings.customWakeTime, isNull);
      expect(settings.bedtimeReminderOn, isFalse);
      expect(settings.wakeAlarmOn, isFalse);
      expect(settings.alarmDays, equals([1, 2, 3, 4, 5, 6, 7]));
      expect(settings.alarmSound, equals('Gentle Chime'));
      expect(settings.vibrate, isTrue);
      expect(settings.snoozeMinutes, equals(10));
    });

    test('serializes and deserializes to JSON correctly', () {
      const original = SleepSettings(
        workStart: TimeOfDay(hour: 8, minute: 30),
        workEnd: TimeOfDay(hour: 17, minute: 45),
        sleepMinutes: 480,
        customBedtime: TimeOfDay(hour: 22, minute: 15),
        customWakeTime: TimeOfDay(hour: 6, minute: 30),
        bedtimeReminderOn: true,
        wakeAlarmOn: true,
        alarmDays: [1, 2, 3, 4, 5],
        alarmSound: 'Morning Breeze',
        vibrate: false,
        snoozeMinutes: 15,
      );

      final json = original.toJson();
      final restored = SleepSettings.fromJson(json);

      expect(restored.workStart, equals(const TimeOfDay(hour: 8, minute: 30)));
      expect(restored.workEnd, equals(const TimeOfDay(hour: 17, minute: 45)));
      expect(restored.sleepMinutes, equals(480));
      expect(restored.customBedtime, equals(const TimeOfDay(hour: 22, minute: 15)));
      expect(restored.customWakeTime, equals(const TimeOfDay(hour: 6, minute: 30)));
      expect(restored.bedtimeReminderOn, isTrue);
      expect(restored.wakeAlarmOn, isTrue);
      expect(restored.alarmDays, equals([1, 2, 3, 4, 5]));
      expect(restored.alarmSound, equals('Morning Breeze'));
      expect(restored.vibrate, isFalse);
      expect(restored.snoozeMinutes, equals(15));
    });

    test('copyWith works for setting and clearing custom fields', () {
      const original = SleepSettings(
        customBedtime: TimeOfDay(hour: 23, minute: 0),
        customWakeTime: TimeOfDay(hour: 7, minute: 0),
        sleepMinutes: 480,
      );

      final updated = original.copyWith(
        customBedtime: const TimeOfDay(hour: 22, minute: 30),
        alarmSound: 'Energy Rise',
      );
      expect(updated.customBedtime, equals(const TimeOfDay(hour: 22, minute: 30)));
      expect(updated.alarmSound, equals('Energy Rise'));

      final cleared = updated.copyWith(
        clearCustomBedtime: true,
        clearCustomWakeTime: true,
        clearSleepMinutes: true,
      );
      expect(cleared.customBedtime, isNull);
      expect(cleared.customWakeTime, isNull);
      expect(cleared.sleepMinutes, isNull);
    });
  });

  group('SharedPrefsSleepRepository', () {
    test('persists and loads settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsSleepRepository(prefs);

      // Initially default
      final initial = await repo.loadSettings();
      expect(initial.wakeAlarmOn, isFalse);
      expect(initial.customBedtime, isNull);

      // Save custom settings
      const toSave = SleepSettings(
        customBedtime: TimeOfDay(hour: 21, minute: 45),
        customWakeTime: TimeOfDay(hour: 5, minute: 45),
        wakeAlarmOn: true,
        alarmSound: 'Classic Bell',
        snoozeMinutes: 5,
      );
      await repo.saveSettings(toSave);

      // Load back
      final loaded = await repo.loadSettings();
      expect(loaded.wakeAlarmOn, isTrue);
      expect(loaded.customBedtime, equals(const TimeOfDay(hour: 21, minute: 45)));
      expect(loaded.customWakeTime, equals(const TimeOfDay(hour: 5, minute: 45)));
      expect(loaded.alarmSound, equals('Classic Bell'));
      expect(loaded.snoozeMinutes, equals(5));
    });
  });
}
