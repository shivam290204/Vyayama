import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/features/health_profile/data/async_value_x.dart';
import 'package:fitbuddy/features/health_profile/data/profile_snapshot.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/providers.dart';
import 'package:fitbuddy/features/sleep/data/day_time_convert.dart';
import 'package:fitbuddy/features/sleep/data/mock_sleep_repository.dart';
import 'package:fitbuddy/features/sleep/data/shared_prefs_sleep_repository.dart';
import 'package:fitbuddy/features/sleep/data/sleep_repository.dart';
import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';
import 'package:fitbuddy/features/sleep/reminders/sleep_reminder_builders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Repository for sleep settings.
/// Uses SharedPreferences for persistent local storage, fallback to Mock.
final sleepRepositoryProvider = Provider<SleepRepository>(
  (ref) {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      return SharedPrefsSleepRepository(prefs);
    } catch (_) {
      return MockSleepRepository();
    }
  },
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
    this.customBedtime,
    this.customWakeTime,
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

  /// Custom bedtime if set.
  final TimeOfDay? customBedtime;

  /// Custom wake-up (alarm) time if set.
  final TimeOfDay? customWakeTime;
}

/// Computes [SleepInputs] from settings and optional profile snapshot.
SleepInputs buildSleepInputs({
  required SleepSettings settings,
  required ProfileSnapshot? profile,
}) {
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
    customBedtime: settings.customBedtime,
    customWakeTime: settings.customWakeTime,
  );
}

/// Builds a [SleepPlan] from [SleepInputs].
SleepPlan buildSleepPlan(SleepInputs inputs) {
  return SleepPlanner.plan(
    workStart: inputs.workStart.toDayTime(),
    workEnd: inputs.workEnd.toDayTime(),
    goal: inputs.goal,
    sleepMinutes: inputs.sleepMinutes,
    customBedtime: inputs.customBedtime?.toDayTime(),
    customWakeTime: inputs.customWakeTime?.toDayTime(),
  );
}

/// Planner inputs with profile prefill.
final sleepInputsProvider = Provider<SleepInputs>((ref) {
  final settings =
      ref.watch(sleepSettingsProvider).dataOrNull ?? const SleepSettings();
  final profile = ref.watch(profileSnapshotProvider).dataOrNull;
  return buildSleepInputs(settings: settings, profile: profile);
});

/// The suggested bedtime and wake time.
final sleepPlanProvider = Provider<SleepPlan>((ref) {
  final inputs = ref.watch(sleepInputsProvider);
  return buildSleepPlan(inputs);
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

  /// Sets custom bedtime directly.
  Future<void> setCustomBedtime(TimeOfDay? time) => _apply(
        time == null
            ? _current.copyWith(clearCustomBedtime: true)
            : _current.copyWith(customBedtime: time),
      );

  /// Sets custom wake-up (alarm) time directly.
  Future<void> setCustomWakeTime(TimeOfDay? time) => _apply(
        time == null
            ? _current.copyWith(clearCustomWakeTime: true)
            : _current.copyWith(customWakeTime: time),
      );

  /// Resets custom bedtime and wake-up times back to suggested algorithm.
  Future<void> resetToSuggested() => _apply(
        _current.copyWith(
          clearCustomBedtime: true,
          clearCustomWakeTime: true,
          clearSleepMinutes: true,
        ),
      );

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

  /// Sets repeating days for the alarm.
  Future<void> setAlarmDays(List<int> days) =>
      _apply(_current.copyWith(alarmDays: days));

  /// Sets the chosen alarm sound.
  Future<void> setAlarmSound(String sound) =>
      _apply(_current.copyWith(alarmSound: sound));

  /// Sets vibration toggle for the alarm.
  Future<void> setVibrate(bool vibrate) =>
      _apply(_current.copyWith(vibrate: vibrate));

  /// Sets snooze duration in minutes.
  Future<void> setSnoozeMinutes(int minutes) =>
      _apply(_current.copyWith(snoozeMinutes: minutes));

  /// Turns the bedtime (wind-down) reminder on or off.
  Future<void> setBedtimeReminder(bool on) =>
      _apply(_current.copyWith(bedtimeReminderOn: on));

  /// Turns the alarm-style wake-up reminder on or off.
  Future<void> setWakeAlarm(bool on) =>
      _apply(_current.copyWith(wakeAlarmOn: on));

  SleepPlan _computePlan(SleepSettings settings) {
    final profile = ref.read(profileSnapshotProvider).dataOrNull;
    final inputs = buildSleepInputs(settings: settings, profile: profile);
    return buildSleepPlan(inputs);
  }

  /// Re-schedules reminders from the current plan. Call after the profile
  /// loads or after a reboot or time-zone change.
  Future<void> resync() => _syncReminders(_current, _computePlan(_current));

  Future<void> _apply(SleepSettings next) async {
    final previous = _current;
    state = AsyncData<SleepSettings>(next);
    try {
      await ref.read(sleepRepositoryProvider).saveSettings(next);
    } catch (e) {
      debugPrint('SleepSettings saveSettings error: $e');
      state = AsyncData<SleepSettings>(previous);
      rethrow;
    }

    final plan = _computePlan(next);
    try {
      await _syncReminders(next, plan);
    } catch (e) {
      debugPrint('SleepSettings _syncReminders non-fatal error: $e');
    }

    try {
      await _syncScheduleBlocks(plan);
    } catch (e) {
      debugPrint('SleepSettings _syncScheduleBlocks non-fatal error: $e');
    }
  }

  Future<void> _syncScheduleBlocks(SleepPlan plan) async {
    try {
      final blocks = ref.read(scheduleBlocksProvider).asData?.value;
      if (blocks == null) return;
      final wakeBlock =
          blocks.where((b) => b.type == BlockType.wake).firstOrNull;
      final sleepBlock =
          blocks.where((b) => b.type == BlockType.sleep).firstOrNull;
      final notifier = ref.read(scheduleBlocksProvider.notifier);
      if (wakeBlock != null && wakeBlock.startMinutes != plan.wakeTime.minutes) {
        await notifier
            .save(wakeBlock.copyWith(startMinutes: plan.wakeTime.minutes));
      }
      if (sleepBlock != null &&
          sleepBlock.startMinutes != plan.bedtime.minutes) {
        await notifier
            .save(sleepBlock.copyWith(startMinutes: plan.bedtime.minutes));
      }
    } catch (e) {
      debugPrint('SleepSettings _syncScheduleBlocks error: $e');
    }
  }

  Future<void> _syncReminders(SleepSettings settings, SleepPlan plan) async {
    try {
      final scheduler = ref.read(reminderSchedulerProvider);
      await scheduler.cancel(bedtimeReminderId);
      await scheduler.cancel(wakeAlarmReminderId);
      if (settings.bedtimeReminderOn) {
        await scheduler.schedule(buildBedtimeReminder(plan));
      }
      if (settings.wakeAlarmOn) {
        await scheduler.schedule(buildWakeAlarm(plan));
      }
    } catch (e) {
      debugPrint('SleepSettings _syncReminders error: $e');
    }
  }
}

/// Tracks which wind-down items are ticked, persisted in SharedPreferences.
class WindDownNotifier extends Notifier<Set<String>> {
  static const String _windDownKey = 'vyayama_wind_down_items';

  @override
  Set<String> build() {
    try {
      final prefs = ref.watch(sharedPreferencesProvider);
      final list = prefs.getStringList(_windDownKey);
      if (list != null) return list.toSet();
    } catch (_) {}
    return <String>{};
  }

  /// Ticks or unticks the item with [id].
  void toggle(String id) {
    final next = Set<String>.of(state);
    if (!next.remove(id)) next.add(id);
    state = next;
    _persist(next);
  }

  /// Clears all ticks.
  void reset() {
    state = <String>{};
    _persist(state);
  }

  void _persist(Set<String> items) {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      prefs.setStringList(_windDownKey, items.toList());
    } catch (_) {}
  }
}

