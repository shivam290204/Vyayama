import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/intelligence/data/fitness_preferences_repository.dart';
import 'package:fitbuddy/features/intelligence/domain/models/user_fitness_preferences.dart';

void main() {
  group('UserFitnessPreferences Unit Tests', () {
    test('Defaults factory produces safe initial configuration', () {
      final defaults = UserFitnessPreferences.defaults(userId: 'u_test');

      expect(defaults.userId, 'u_test');
      expect(defaults.availableEquipment, contains('none'));
      expect(defaults.availableEquipment, contains('dumbbells'));
      expect(defaults.dailyWorkoutMinutes, 30);
      expect(defaults.preferredWorkoutTime, 'flexible');
      expect(defaults.preferredTimeEnum, PreferredWorkoutTime.flexible);
      expect(defaults.durationOption, WorkoutDurationOption.thirty);
    });

    test('Json roundtrip preserves all preferences', () {
      final prefs = UserFitnessPreferences(
        userId: 'u_123',
        availableEquipment: const ['bands', 'barbell'],
        dailyWorkoutMinutes: 45,
        preferredWorkoutTime: 'morning',
        updatedAt: DateTime.utc(2026, 10, 29, 12, 0),
      );

      final json = prefs.toJson();
      final restored = UserFitnessPreferences.fromJson(json);

      expect(restored.userId, 'u_123');
      expect(restored.availableEquipment, ['bands', 'barbell']);
      expect(restored.dailyWorkoutMinutes, 45);
      expect(restored.preferredWorkoutTime, 'morning');
      expect(restored.preferredTimeEnum, PreferredWorkoutTime.morning);
      expect(restored.durationOption, WorkoutDurationOption.fortyFive);
    });

    test('Missing fields in Json fallback to defaults without errors', () {
      final restored = UserFitnessPreferences.fromJson({});

      expect(restored.userId, 'local_user');
      expect(restored.availableEquipment, contains('none'));
      expect(restored.dailyWorkoutMinutes, 30);
      expect(restored.preferredWorkoutTime, 'flexible');
    });

    test('WorkoutDurationOption mapping covers all durations', () {
      expect(WorkoutDurationOption.fromMinutes(10), WorkoutDurationOption.ten);
      expect(WorkoutDurationOption.fromMinutes(15), WorkoutDurationOption.fifteen);
      expect(WorkoutDurationOption.fromMinutes(20), WorkoutDurationOption.twenty);
      expect(WorkoutDurationOption.fromMinutes(30), WorkoutDurationOption.thirty);
      expect(WorkoutDurationOption.fromMinutes(45), WorkoutDurationOption.fortyFive);
      expect(WorkoutDurationOption.fromMinutes(60), WorkoutDurationOption.sixtyOrMore);
      expect(WorkoutDurationOption.fromMinutes(90), WorkoutDurationOption.sixtyOrMore);
    });

    test('WorkoutEquipment id resolution falls back safely', () {
      expect(WorkoutEquipment.fromId('none'), WorkoutEquipment.bodyweight);
      expect(WorkoutEquipment.fromId('dumbbells'), WorkoutEquipment.dumbbells);
      expect(WorkoutEquipment.fromId('bands'), WorkoutEquipment.bands);
      expect(WorkoutEquipment.fromId('barbell'), WorkoutEquipment.barbell);
      expect(WorkoutEquipment.fromId('gym'), WorkoutEquipment.gym);
      expect(WorkoutEquipment.fromId('unknown_gear'), WorkoutEquipment.bodyweight);
    });
  });

  group('SharedPrefsFitnessPreferencesRepository Tests', () {
    late SharedPreferences prefs;
    late SharedPrefsFitnessPreferencesRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = SharedPrefsFitnessPreferencesRepository(prefs: prefs);
    });

    test('getPreferences for non-existent user returns default configuration', () async {
      final result = await repo.getPreferences('u_new');

      expect(result.userId, 'u_new');
      expect(result.availableEquipment, contains('none'));
      expect(result.dailyWorkoutMinutes, 30);
    });

    test('savePreferences persists and can be reloaded across instances', () async {
      final userPrefs = UserFitnessPreferences(
        userId: 'u_fit',
        availableEquipment: const ['gym'],
        dailyWorkoutMinutes: 60,
        preferredWorkoutTime: 'early_morning',
      );

      await repo.savePreferences(userPrefs);

      final secondRepo = SharedPrefsFitnessPreferencesRepository(prefs: prefs);
      final loaded = await secondRepo.getPreferences('u_fit');

      expect(loaded.userId, 'u_fit');
      expect(loaded.availableEquipment, ['gym']);
      expect(loaded.dailyWorkoutMinutes, 60);
      expect(loaded.preferredWorkoutTime, 'early_morning');
    });

    test('Preferences are isolated between multiple users on the same device', () async {
      final user1 = UserFitnessPreferences(
        userId: 'user_1',
        availableEquipment: const ['none'],
        dailyWorkoutMinutes: 15,
        preferredWorkoutTime: 'morning',
      );
      final user2 = UserFitnessPreferences(
        userId: 'user_2',
        availableEquipment: const ['barbell', 'gym'],
        dailyWorkoutMinutes: 45,
        preferredWorkoutTime: 'evening',
      );

      await repo.savePreferences(user1);
      await repo.savePreferences(user2);

      final loaded1 = await repo.getPreferences('user_1');
      final loaded2 = await repo.getPreferences('user_2');

      expect(loaded1.dailyWorkoutMinutes, 15);
      expect(loaded1.availableEquipment, ['none']);

      expect(loaded2.dailyWorkoutMinutes, 45);
      expect(loaded2.availableEquipment, ['barbell', 'gym']);
    });
  });
}

