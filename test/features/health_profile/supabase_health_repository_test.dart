import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/data/supabase_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SupabaseHealthRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = SupabaseHealthRepository(prefs: prefs, client: null);
  });

  group('SupabaseHealthRepository (Offline / Local Cache fallback)', () {
    test('starts with empty medicines', () async {
      final list = await repo.listMedicines();
      expect(list, isEmpty);
    });

    test('saves and lists medicine with valid UUID id', () async {
      final saved = await repo.saveMedicine(
        const Medicine(
          id: '',
          name: 'Metformin',
          reminderTimes: [TimeOfDay(hour: 8, minute: 30)],
          isActive: true,
        ),
      );

      expect(saved.id, isNotEmpty);
      // Valid RFC 4122 UUID v4 regex
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
            .hasMatch(saved.id),
        isTrue,
      );
      expect(saved.name, equals('Metformin'));
      expect(saved.reminderTimes.length, equals(1));
      expect(saved.reminderTimes.first.hour, equals(8));
      expect(saved.reminderTimes.first.minute, equals(30));

      final list = await repo.listMedicines();
      expect(list.length, equals(1));
      expect(list.first.name, equals('Metformin'));
      expect(list.first.isActive, isTrue);
    });

    test('updates existing medicine', () async {
      final saved = await repo.saveMedicine(
        const Medicine(
          id: '',
          name: 'Aspirin',
          reminderTimes: [TimeOfDay(hour: 12, minute: 0)],
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
          name: 'Omeprazole',
          reminderTimes: [TimeOfDay(hour: 7, minute: 0)],
        ),
      );

      await repo.deleteMedicine(saved.id);
      final list = await repo.listMedicines();
      expect(list, isEmpty);
    });

    test('saves and retrieves selected condition keys', () async {
      final initial = await repo.getSelectedConditionKeys();
      expect(initial, isEmpty);

      await repo.saveSelectedConditionKeys(['lower_back_pain', 'hypertension']);
      final reloaded = await repo.getSelectedConditionKeys();
      expect(reloaded, equals(['lower_back_pain', 'hypertension']));
    });

    test('saves and retrieves meal reminders', () async {
      final defaults = await repo.getMealReminders();
      expect(defaults.of(MealSlot.breakfast).time.hour, equals(8));

      final updated = defaults.withSlot(
        MealSlot.dinner,
        const MealReminder(time: TimeOfDay(hour: 20, minute: 15), enabled: true),
      );

      await repo.saveMealReminders(updated);
      final reloaded = await repo.getMealReminders();
      expect(reloaded.of(MealSlot.dinner).time.hour, equals(20));
      expect(reloaded.of(MealSlot.dinner).time.minute, equals(15));
    });
  });
}
