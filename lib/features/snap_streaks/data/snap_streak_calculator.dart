import 'dart:math' as math;

import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// What a pair looks like to one of its members right now.
enum PairStatus {
  none,
  waitingOnFriend,
  yourTurn,
  completedToday,
  atRisk,
  broken,
}

/// What happened when a snap was applied to a streak.
enum StreakEvent { nudgeFriend, completed, alreadyCompleted, ignored }

/// Result of [SnapStreakCalculator.applySnap].
class StreakUpdate {
  const StreakUpdate({required this.streak, required this.event, this.milestone});

  final SnapStreak streak;
  final StreakEvent event;

  /// Set when this update reached a milestone day (3, 7, 14, 30, 50, 100).
  final int? milestone;
}

/// Pure Dart mirror of the server logic in spec section 9.6 and the SQL
/// functions in `supabase/migrations/100_snap_streak_functions.sql`.
///
/// Keep the two in sync. Timezone data is initialised lazily.
abstract final class SnapStreakCalculator {
  static const List<int> milestones = [3, 7, 14, 30, 50, 100];
  static const Duration atRiskWindow = Duration(hours: 4);
  static bool _tzReady = false;

  /// Loads timezone data once. Safe to call many times.
  static void ensureTimezones() {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    _tzReady = true;
  }

  static tz.Location _location(String name) {
    ensureTimezones();
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.UTC;
    }
  }

  /// The calendar day (as UTC midnight) of [nowUtc] in [timezone].
  static DateTime localDate(DateTime nowUtc, String timezone) {
    final t = tz.TZDateTime.from(nowUtc.toUtc(), _location(timezone));
    return DateTime.utc(t.year, t.month, t.day);
  }

  /// Time left until the streak day ends in [timezone].
  static Duration timeLeftToday(DateTime nowUtc, String timezone) {
    final loc = _location(timezone);
    final t = tz.TZDateTime.from(nowUtc.toUtc(), loc);
    final next = tz.TZDateTime(loc, t.year, t.month, t.day + 1);
    return next.difference(t);
  }

  /// Applies a snap sent by [sender] to [streak].
  ///
  /// Rejected, pending and Friends Feed snaps never count.
  static StreakUpdate applySnap({
    required SnapStreak streak,
    required StreakSide sender,
    required DateTime nowUtc,
    bool verified = true,
    bool isStory = false,
  }) {
    if (!verified || isStory) {
      return StreakUpdate(streak: streak, event: StreakEvent.ignored);
    }
    final today = localDate(nowUtc, streak.timezone);
    var s = sender == StreakSide.a
        ? streak.copyWith(lastASnapDate: today)
        : streak.copyWith(lastBSnapDate: today);

    final bothSent = s.lastASnapDate == today && s.lastBSnapDate == today;
    if (!bothSent) {
      return StreakUpdate(streak: s, event: StreakEvent.nudgeFriend);
    }
    if (s.lastCompletedDate == today) {
      return StreakUpdate(streak: s, event: StreakEvent.alreadyCompleted);
    }
    final yesterday = today.subtract(const Duration(days: 1));
    final continues = s.lastCompletedDate == yesterday;
    final next = continues ? s.current + 1 : 1;
    s = s.copyWith(
      current: next,
      longest: math.max(s.longest, next),
      lastCompletedDate: today,
    );
    return StreakUpdate(
      streak: s,
      event: StreakEvent.completed,
      milestone: milestones.contains(next) ? next : null,
    );
  }

  /// The streak count after the hourly job: 0 once a full day was missed.
  static int effectiveCurrent(SnapStreak s, DateTime nowUtc) {
    if (s.current <= 0) return 0;
    final last = s.lastCompletedDate;
    if (last == null) return 0;
    final today = localDate(nowUtc, s.timezone);
    return today.difference(last).inDays >= 2 ? 0 : s.current;
  }

  /// Mirrors `reset_expired_streaks()`: resets [s] if a full day was missed.
  static SnapStreak expireIfMissed(SnapStreak s, DateTime nowUtc) {
    if (s.current > 0 && effectiveCurrent(s, nowUtc) == 0) {
      return s.copyWith(current: 0);
    }
    return s;
  }

  /// True when a live streak is not complete today and under 4 hours remain.
  static bool isAtRisk(SnapStreak s, DateTime nowUtc) {
    if (effectiveCurrent(s, nowUtc) == 0) return false;
    final today = localDate(nowUtc, s.timezone);
    if (s.lastCompletedDate == today) return false;
    return timeLeftToday(nowUtc, s.timezone) <= atRiskWindow;
  }

  /// True when the friend sent today and [myId] has not (the "worried" case).
  static bool friendSentIAmNot(SnapStreak s, String myId, DateTime nowUtc) {
    final side = s.sideOf(myId);
    if (side == null) return false;
    final today = localDate(nowUtc, s.timezone);
    return s.lastSnapOf(side.other) == today && s.lastSnapOf(side) != today;
  }

  /// The pair status as seen by [myId].
  static PairStatus statusFor(SnapStreak? s, String myId, DateTime nowUtc) {
    if (s == null) return PairStatus.none;
    final side = s.sideOf(myId);
    if (side == null) return PairStatus.none;
    final today = localDate(nowUtc, s.timezone);
    final mine = s.lastSnapOf(side) == today;
    final theirs = s.lastSnapOf(side.other) == today;
    if (mine && theirs) return PairStatus.completedToday;
    if (!mine && isAtRisk(s, nowUtc)) return PairStatus.atRisk;
    if (mine) return PairStatus.waitingOnFriend;
    if (theirs) return PairStatus.yourTurn;
    if (effectiveCurrent(s, nowUtc) == 0 && s.longest > 0) {
      return PairStatus.broken;
    }
    return PairStatus.none;
  }

  /// The days that make up the current streak, newest first.
  static List<DateTime> completedDays(SnapStreak s, DateTime nowUtc) {
    final last = s.lastCompletedDate;
    final cur = effectiveCurrent(s, nowUtc);
    if (last == null || cur == 0) return const [];
    return [for (var i = 0; i < cur; i++) last.subtract(Duration(days: i))];
  }
}
