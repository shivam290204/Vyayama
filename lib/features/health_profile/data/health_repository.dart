import 'package:fitbuddy/features/health_profile/data/condition_rule.dart';
import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';

/// Storage for conditions, medicines and meal reminder times.
///
/// Antigravity: back conditions with `user_conditions`, medicines with
/// `medicines`, and meal times with `schedule_blocks` (type `meal`) or
/// `shared_preferences`.
abstract class HealthRepository {
  /// Loads every condition rule from `assets/data/conditions.json`.
  Future<List<ConditionRule>> loadConditionRules();

  /// Condition keys the user selected.
  Future<List<String>> getSelectedConditionKeys();

  /// Replaces the user's selected condition keys.
  Future<void> saveSelectedConditionKeys(List<String> keys);

  /// All medicine reminders.
  Future<List<Medicine>> listMedicines();

  /// Inserts (empty id) or updates a medicine and returns the stored row.
  Future<Medicine> saveMedicine(Medicine medicine);

  /// Deletes a medicine.
  Future<void> deleteMedicine(String id);

  /// Meal reminder times.
  Future<MealReminderSettings> getMealReminders();

  /// Saves meal reminder times.
  Future<void> saveMealReminders(MealReminderSettings settings);
}
