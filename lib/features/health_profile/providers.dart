import 'package:fitbuddy/features/health_profile/data/async_value_x.dart';
import 'package:fitbuddy/features/health_profile/data/condition_rule.dart';
import 'package:fitbuddy/features/health_profile/data/health_repository.dart';
import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/data/mock_health_repository.dart';
import 'package:fitbuddy/features/health_profile/data/profile_snapshot.dart';
import 'package:fitbuddy/features/health_profile/domain/condition_tags.dart';
import 'package:fitbuddy/features/health_profile/reminders/mock_reminder_scheduler.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_builders.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_scheduler.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for conditions, medicines and meal reminder times.
/// Antigravity: override with a Supabase-backed implementation.
final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => MockHealthRepository(),
);

/// Reminder scheduler. Antigravity: override with a
/// `flutter_local_notifications` implementation.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => MockReminderScheduler(),
);

/// Plain-value view of the signed-in user's profile (shared by nutrition,
/// sleep and teams).
final profileSnapshotProvider = Provider<AsyncValue<ProfileSnapshot?>>((ref) {
  final AsyncValue<dynamic> profile = ref.watch(currentProfileProvider);
  return profile.when<AsyncValue<ProfileSnapshot?>>(
    data: (value) => AsyncData<ProfileSnapshot?>(
      value == null ? null : ProfileSnapshot.fromProfile(value),
    ),
    loading: () => const AsyncLoading<ProfileSnapshot?>(),
    error: (error, stack) => AsyncError<ProfileSnapshot?>(error, stack),
  );
});

/// All condition rules loaded from `assets/data/conditions.json`.
final conditionRulesProvider = FutureProvider<List<ConditionRule>>(
  (ref) => ref.watch(healthRepositoryProvider).loadConditionRules(),
);

/// The condition keys the user selected (for example `knee_pain`).
final selectedConditionKeysProvider =
    AsyncNotifierProvider<SelectedConditionsNotifier, List<String>>(
  SelectedConditionsNotifier.new,
);

/// Combined exercise-contraindication tags for the user's selected
/// conditions (for example `knee`, `lower_back`, `shoulder`, `high_impact`).
/// Empty while loading or when nothing is selected.
final selectedConditionTagsProvider = Provider<List<String>>((ref) {
  final rules =
      ref.watch(conditionRulesProvider).dataOrNull ?? const <ConditionRule>[];
  final keys = ref.watch(selectedConditionKeysProvider).dataOrNull ??
      const <String>[];
  return combineConditionTags(rules, keys);
});

/// The user's medicine reminders (name and times only).
final medicinesProvider =
    AsyncNotifierProvider<MedicinesNotifier, List<Medicine>>(
  MedicinesNotifier.new,
);

/// Meal reminder times (breakfast, lunch, snack, dinner).
final mealRemindersProvider =
    AsyncNotifierProvider<MealRemindersNotifier, MealReminderSettings>(
  MealRemindersNotifier.new,
);

/// Holds the selected condition keys and persists changes.
class SelectedConditionsNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() =>
      ref.watch(healthRepositoryProvider).getSelectedConditionKeys();

  /// Selects or unselects a condition. "none" clears every other choice.
  Future<void> toggle(String key) async {
    final current = state.dataOrNull ?? const <String>[];
    final next = toggleCondition(current, key);
    state = AsyncData<List<String>>(next);
    try {
      await ref.read(healthRepositoryProvider).saveSelectedConditionKeys(next);
    } catch (_) {
      state = AsyncData<List<String>>(current);
      rethrow;
    }
  }
}

/// Holds medicines and keeps scheduled reminders in sync.
class MedicinesNotifier extends AsyncNotifier<List<Medicine>> {
  @override
  Future<List<Medicine>> build() =>
      ref.watch(healthRepositoryProvider).listMedicines();

  /// Adds a medicine (empty id) or updates an existing one.
  Future<void> save(Medicine medicine) async {
    final repo = ref.read(healthRepositoryProvider);
    final scheduler = ref.read(reminderSchedulerProvider);
    final existing = state.dataOrNull ?? const <Medicine>[];
    final old = existing.where((m) => m.id == medicine.id).toList();
    final oldCount = old.isEmpty ? 0 : old.first.reminderTimes.length;

    final saved = await repo.saveMedicine(medicine);
    final cancelCount = oldCount > saved.reminderTimes.length
        ? oldCount
        : saved.reminderTimes.length;
    for (var i = 0; i < cancelCount; i++) {
      await scheduler.cancel(medicineReminderId(saved.id, i));
    }
    if (saved.isActive) {
      for (final request in buildMedicineReminders(saved)) {
        await scheduler.schedule(request);
      }
    }
    state = AsyncData<List<Medicine>>(await repo.listMedicines());
  }

  /// Turns reminders for one medicine on or off.
  Future<void> setActive(Medicine medicine, bool active) =>
      save(medicine.copyWith(isActive: active));

  /// Deletes a medicine and cancels its reminders.
  Future<void> delete(Medicine medicine) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    for (var i = 0; i < medicine.reminderTimes.length; i++) {
      await scheduler.cancel(medicineReminderId(medicine.id, i));
    }
    final repo = ref.read(healthRepositoryProvider);
    await repo.deleteMedicine(medicine.id);
    state = AsyncData<List<Medicine>>(await repo.listMedicines());
  }
}

/// Holds meal reminder times and keeps scheduled reminders in sync.
class MealRemindersNotifier extends AsyncNotifier<MealReminderSettings> {
  @override
  Future<MealReminderSettings> build() =>
      ref.watch(healthRepositoryProvider).getMealReminders();

  /// Changes the time and/or enabled flag for one meal.
  Future<void> updateSlot(
    MealSlot slot, {
    TimeOfDay? time,
    bool? enabled,
  }) async {
    final current = state.dataOrNull ?? MealReminderSettings.defaults();
    final updated = current.of(slot).copyWith(time: time, enabled: enabled);
    final next = current.withSlot(slot, updated);
    state = AsyncData<MealReminderSettings>(next);

    final scheduler = ref.read(reminderSchedulerProvider);
    await ref.read(healthRepositoryProvider).saveMealReminders(next);
    await scheduler.cancel(mealReminderId(slot));
    if (updated.enabled) {
      await scheduler.schedule(buildMealReminder(slot, updated));
    }
  }
}
