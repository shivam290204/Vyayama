import 'package:fitbuddy/features/health_profile/data/async_value_x.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/features/sleep/data/day_time_convert.dart';
import 'package:fitbuddy/features/sleep/data/mock_sleep_repository.dart';
import 'package:fitbuddy/features/sleep/data/sleep_repository.dart';
import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';
import 'package:fitbuddy/features/sleep/reminders/sleep_reminder_builders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for sleep settings.
/// Antigravity: override with a persistent implementation.
final sleepRepositoryProvider = Provider<SleepRepository>(
  (ref) => MockSleepRepository(),
);

/// The user's sleep settings and reminder toggles.
final sleepSettingsProvider =
    AsyncNotifierProvider<SleepSettingsNotifier, SleepSettings>(
  SleepSettingsNotifier.new,
);

/// Inputs the planner uses, after applying profile prefill and defaults.
class SleepInputs {
  /// Creates the inputs.
  const SleepInputs({
    required this.workStart,
    required this.workEnd,
    required this.goal,
    required this.sleepMinutes,
    required this.isCustomLength,
  });

  /// Work start (settings, then profile, then 09:00).
  final TimeOfDay workStart;

  /// Work end (settings, then profile, then 17:00).
  final TimeOfDay workEnd;

  /// `lose`, `gain`, `maintain` or null.
  final String? goal;

  /// Chosen or goal-based sleep length in minutes.
  final int sleepMinutes;

  /// True when the user picked the length themselves.
  final bool isCustomLength;
}

/// Planner inputs with profile prefill.
final sleepInputsProvider = Provider<SleepInputs>((ref) {
  final settings =
      ref.watch(sleepSettingsProvider).dataOrNull ?? const SleepSettings();
  final profile = ref.watch(profileSnapshotProvider).dataOrNull;
  final goal = profile?.goal;
  return SleepInputs(
    workStart: settings.workStart ??
        profile?.workStart ??
        const TimeOfDay(hour: 9, minute: 0),
    workEnd: settings.workEnd ??
        profile?.workEnd ??
        const TimeOfDay(hour: 17, minute: 0),
    goal: goal,
    sleepMinutes:
        settings.sleepMinutes ?? SleepPlanner.defaultSleepMinutes(goal),
    isCustomLength: settings.sleepMinutes != null,
  );
});

/// The suggested bedtime and wake time.
final sleepPlanProvider = Provider<SleepPlan>((ref) {
  final inputs = ref.watch(sleepInputsProvider);
  return SleepPlanner.plan(
    workStart: inputs.workStart.toDayTime(),
    workEnd: inputs.workEnd.toDayTime(),
    goal: inputs.goal,
    sleepMinutes: inputs.sleepMinutes,
  );
});

/// Tips for one sleep category (`sleep_eat` or `sleep_avoid`).
final sleepTipsProvider =
    Provider.family<AsyncValue<List<DietTip>>, String>((ref, category) {
  return ref
      .watch(dietTipsProvider)
      .whenData((tips) => tips.where((t) => t.category == category).toList());
});

/// Wind-down checklist ticks for this session.
final windDownProvider = NotifierProvider<WindDownNotifier, Set<String>>(
  WindDownNotifier.new,
);

/// Holds sleep settings, saves them and keeps reminders in sync.
class SleepSettingsNotifier extends AsyncNotifier<SleepSettings> {
  @override
  Future<SleepSettings> build() =>
      ref.watch(sleepRepositoryProvider).loadSettings();

  SleepSettings get _current => state.dataOrNull ?? const SleepSettings();

  /// Sets the work start time.
  Future<void> setWorkStart(TimeOfDay time) =>
      _apply(_current.copyWith(workStart: time));

  /// Sets the work end time.
  Future<void> setWorkEnd(TimeOfDay time) =>
      _apply(_current.copyWith(workEnd: time));

  /// Sets the sleep length in minutes, or null to use the suggested length.
  Future<void> setSleepMinutes(int? minutes) => _apply(
        minutes == null
            ? _current.copyWith(clearSleepMinutes: true)
            : _current.copyWith(
                sleepMinutes: minutes
                    .clamp(
                      SleepPlanner.minSleepMinutes,
                      SleepPlanner.maxSleepMinutes,
                    )
                    .toInt(),
              ),
      );

  /// Turns the bedtime (wind-down) reminder on or off.
  Future<void> setBedtimeReminder(bool on) =>
      _apply(_current.copyWith(bedtimeReminderOn: on));

  /// Turns the alarm-style wake-up reminder on or off.
  Future<void> setWakeAlarm(bool on) =>
      _apply(_current.copyWith(wakeAlarmOn: on));

  /// Re-schedules reminders from the current plan. Call after the profile
  /// loads or after a reboot or time-zone change.
  Future<void> resync() => _syncReminders(_current);

  Future<void> _apply(SleepSettings next) async {
    final previous = _current;
    state = AsyncData<SleepSettings>(next);
    try {
      await ref.read(sleepRepositoryProvider).saveSettings(next);
      await _syncReminders(next);
    } catch (_) {
      state = AsyncData<SleepSettings>(previous);
      rethrow;
    }
  }

  Future<void> _syncReminders(SleepSettings settings) async {
    final scheduler = ref.read(reminderSchedulerProvider);
    final plan = ref.read(sleepPlanProvider);
    await scheduler.cancel(bedtimeReminderId);
    await scheduler.cancel(wakeAlarmReminderId);
    if (settings.bedtimeReminderOn) {
      await scheduler.schedule(buildBedtimeReminder(plan));
    }
    if (settings.wakeAlarmOn) {
      await scheduler.schedule(buildWakeAlarm(plan));
    }
  }
}

/// Tracks which wind-down items are ticked.
class WindDownNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  /// Ticks or unticks the item with [id].
  void toggle(String id) {
    final next = Set<String>.of(state);
    if (!next.remove(id)) next.add(id);
    state = next;
  }

  /// Clears all ticks.
  void reset() => state = <String>{};
}
