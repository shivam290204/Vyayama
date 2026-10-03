import 'package:fitbuddy/features/sleep/domain/day_time.dart';

/// Friendly heads-ups the planner can raise.
enum SleepWarning {
  /// Work ends close to bedtime, so the evening is short.
  shortEvening,

  /// The schedule leaves less than 7 hours for sleep.
  shortSleep,

  /// The suggested bedtime falls inside work hours.
  bedtimeDuringWork,
}

/// A suggested sleep plan.
class SleepPlan {
  /// Creates a plan.
  const SleepPlan({
    required this.bedtime,
    required this.wakeTime,
    required this.sleepMinutes,
    required this.windDownStart,
    required this.isNightShift,
    this.warnings = const <SleepWarning>[],
  });

  /// Suggested bedtime.
  final DayTime bedtime;

  /// Suggested wake-up time.
  final DayTime wakeTime;

  /// Planned sleep length in minutes.
  final int sleepMinutes;

  /// When to start winding down (one hour before bedtime).
  final DayTime windDownStart;

  /// True when work ends before it starts on the clock (overnight shift).
  final bool isNightShift;

  /// Heads-ups about the schedule.
  final List<SleepWarning> warnings;

  /// Planned sleep length.
  Duration get duration => Duration(minutes: sleepMinutes);
}

/// Pure Dart sleep planner (7 to 9 hours of sleep).
class SleepPlanner {
  const SleepPlanner._();

  /// Shortest suggested sleep: 7 hours.
  static const int minSleepMinutes = 420;

  /// Longest suggested sleep: 9 hours.
  static const int maxSleepMinutes = 540;

  /// Time to get ready (and travel) before work starts.
  static const int prepMinutes = 90;

  /// Wind-down length before bedtime.
  static const int windDownMinutes = 60;

  /// Time between a night shift ending and going to bed.
  static const int nightShiftBufferMinutes = 60;

  /// Work-end to bedtime gaps below this raise [SleepWarning.shortEvening].
  static const int shortEveningMinutes = 180;

  /// Wake time used when no work start is known.
  static final DayTime defaultWake = DayTime(7, 0);

  /// Suggested sleep length for a goal: 8 hours, or 8.5 hours to gain.
  static int defaultSleepMinutes(String? goal) => goal == 'gain' ? 510 : 480;

  /// Builds a plan. Times may cross midnight.
  ///
  /// [sleepMinutes] is clamped to 7 to 9 hours.
  static SleepPlan plan({
    DayTime? workStart,
    DayTime? workEnd,
    String? goal,
    int? sleepMinutes,
  }) {
    final desired = (sleepMinutes ?? defaultSleepMinutes(goal))
        .clamp(minSleepMinutes, maxSleepMinutes)
        .toInt();
    final start = workStart;
    final end = workEnd;
    final warnings = <SleepWarning>[];

    final isNight = start != null && end != null && end.minutes < start.minutes;

    if (isNight) {
      final bedtime = end.plusMinutes(nightShiftBufferMinutes);
      final latestWake = start.minusMinutes(prepMinutes);
      final available = bedtime.minutesUntil(latestWake);
      final length = desired < available ? desired : available;
      if (length < minSleepMinutes) warnings.add(SleepWarning.shortSleep);
      return SleepPlan(
        bedtime: bedtime,
        wakeTime: bedtime.plusMinutes(length),
        sleepMinutes: length,
        windDownStart: bedtime.minusMinutes(windDownMinutes),
        isNightShift: true,
        warnings: warnings,
      );
    }

    final wake =
        start == null ? defaultWake : start.minusMinutes(prepMinutes);
    final bedtime = wake.minusMinutes(desired);

    if (start != null && end != null) {
      if (bedtime.isBetween(start, end)) {
        warnings.add(SleepWarning.bedtimeDuringWork);
      } else if (end.minutesUntil(bedtime) < shortEveningMinutes) {
        warnings.add(SleepWarning.shortEvening);
      }
    }

    return SleepPlan(
      bedtime: bedtime,
      wakeTime: wake,
      sleepMinutes: desired,
      windDownStart: bedtime.minusMinutes(windDownMinutes),
      isNightShift: false,
      warnings: warnings,
    );
  }
}
