import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/data/shared_prefs_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPrefsHealthRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = SharedPrefsHealthRepository(prefs);
  });

  group('SharedPrefsHealthRepository', () {
    test('starts with empty medicines', () async {
      final list = await repo.listMedicines();
      expect(list, isEmpty);
    });

    test('saves and lists medicine', () async {
      final saved = await repo.saveMedicine(
        const Medicine(
          id: '',
          name: 'Paracetamol',
          reminderTimes: [TimeOfDay(hour: 13, minute: 22)],
          isActive: true,
        ),
      );

      expect(saved.id, isNotEmpty);
      expect(saved.name, equals('Paracetamol'));
      expect(saved.reminderTimes.length, equals(1));
      expect(saved.reminderTimes.first.hour, equals(13));
      expect(saved.reminderTimes.first.minute, equals(22));

      final list = await repo.listMedicines();
      expect(list.length, equals(1));
      expect(list.first.name, equals('Paracetamol'));
      expect(list.first.isActive, isTrue);
    });

    test('updates existing medicine', () async {
      final saved = await repo.saveMedicine(
        const Medicine(
          id: '',
          name: 'Vitamin D',
          reminderTimes: [TimeOfDay(hour: 9, minute: 0)],
          isActive: true,
        ),
      );

      final updated = await repo.saveMedicine(
        saved.copyWith(isActive: false),
      );
      expect(updated.isActive, isFalse);

      final list = await repo.listMedicines();
      expect(list.length, equals(1));
      expect(list.first.isActive, isFalse);
    });

    test('deletes medicine', () async {
      final saved = await repo.saveMedicine(
        const Medicine(
          id: '',
          name: 'Ibuprofen',
          reminderTimes: [TimeOfDay(hour: 10, minute: 0)],
        ),
      );

      await repo.deleteMedicine(saved.id);
      final list = await repo.listMedicines();
      expect(list, isEmpty);
    });

    test('saves and retrieves meal reminders', () async {
      final defaults = await repo.getMealReminders();
      expect(defaults.of(MealSlot.breakfast).time.hour, equals(8));

      final updated = defaults.withSlot(
        MealSlot.breakfast,
        const MealReminder(time: TimeOfDay(hour: 7, minute: 30), enabled: true),
      );

      await repo.saveMealReminders(updated);
      final reloaded = await repo.getMealReminders();
      expect(reloaded.of(MealSlot.breakfast).time.hour, equals(7));
      expect(reloaded.of(MealSlot.breakfast).time.minute, equals(30));
    });

    test('saves and retrieves selected conditions', () async {
      final initial = await repo.getSelectedConditionKeys();
      expect(initial, isEmpty);

      await repo.saveSelectedConditionKeys(['knee_pain', 'asthma']);
      final reloaded = await repo.getSelectedConditionKeys();
      expect(reloaded, equals(['knee_pain', 'asthma']));
    });
  });
}
