import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';

/// Result of recording one activity (workout or challenge).
class StreakUpdate {
  /// Creates a result.
  const StreakUpdate({
    required this.state,
    required this.streakChanged,
    required this.xpAwarded,
    this.milestone,
  });

  /// The new state to save.
  final StreakState state;

  /// True when the streak count went up (or restarted at 1).
  final bool streakChanged;

  /// XP added in this update, including any milestone bonus.
  final int xpAwarded;

  /// The streak length reached if it is a milestone day, otherwise null.
  final int? milestone;
}

/// Pure Dart daily-streak rules (spec section 9.4).
///
/// An activity day is a day with a finished workout or daily challenge.
abstract final class StreakLogic {
  /// Streak lengths that trigger a celebration.
  static const List<int> milestones = [3, 7, 14, 30, 50, 100];

  /// Bonus XP for reaching each milestone.
  static const Map<int, int> milestoneBonusXp = {
    3: 10,
    7: 20,
    14: 30,
    30: 50,
    50: 75,
    100: 150,
  };

  /// The calendar day before [d]. Uses date parts, so DST changes cannot
  /// produce the wrong day.
  static DateTime previousDay(DateTime d) =>
      DateTime(d.year, d.month, d.day - 1);

  /// The user's local calendar day for the instant [now].
  ///
  /// Without [utcOffset] the device's local date is used. With it, [now] is
  /// converted to that offset first (for a stored user time zone).
  static DateTime todayFor(DateTime now, {Duration? utcOffset}) {
    if (utcOffset == null) return dayOnly(now);
    final shifted = now.toUtc().add(utcOffset);
    return DateTime(shifted.year, shifted.month, shifted.day);
  }

  /// Streak length to show on [today].
  ///
  /// A streak whose last active day is before yesterday is already broken,
  /// even though the stored value is only reset on the next activity.
  static int effectiveCurrent(StreakState s, DateTime today) {
    final last = s.lastActiveDate;
    if (last == null) return 0;
    final yesterday = previousDay(dayOnly(today));
    return dayOnly(last).isBefore(yesterday) ? 0 : s.current;
  }

  /// Whether an activity was already recorded on [day].
  static bool isActiveOn(StreakState s, DateTime day) {
    final last = s.lastActiveDate;
    return last != null && isSameDay(last, day);
  }

  /// Records an activity on [today] worth [xp] points.
  ///
  /// - last active yesterday: streak + 1
  /// - last active today (or later, for example after travelling west):
  ///   streak unchanged
  /// - otherwise: streak restarts at 1
  ///
  /// [StreakState.longest] follows the streak. XP is always added, plus a
  /// bonus when a milestone is reached.
  static StreakUpdate recordActivity(
    StreakState s, {
    required DateTime today,
    int xp = 0,
  }) {
    final day = dayOnly(today);
    final lastRaw = s.lastActiveDate;
    final last = lastRaw == null ? null : dayOnly(lastRaw);

    final int current;
    final bool changed;
    if (last != null && !last.isBefore(day)) {
      current = s.current;
      changed = false;
    } else if (last != null && last == previousDay(day)) {
      current = s.current + 1;
      changed = true;
    } else {
      current = 1;
      changed = true;
    }

    final int? hit =
        changed && milestones.contains(current) ? current : null;
    final bonus = hit == null ? 0 : (milestoneBonusXp[hit] ?? 0);
    final awarded = (xp < 0 ? 0 : xp) + bonus;

    return StreakUpdate(
      state: s.copyWith(
        current: current,
        longest: current > s.longest ? current : s.longest,
        lastActiveDate: changed ? day : lastRaw,
        xp: s.xp + awarded,
      ),
      streakChanged: changed,
      xpAwarded: awarded,
      milestone: hit,
    );
  }
}
