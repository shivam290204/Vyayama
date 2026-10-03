import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';

/// The user's daily streak and XP. Mirrors table `streaks`.
@immutable
class StreakState {
  /// Creates a state.
  const StreakState({
    required this.userId,
    this.current = 0,
    this.longest = 0,
    this.lastActiveDate,
    this.xp = 0,
  });

  /// A brand-new streak with nothing recorded.
  factory StreakState.empty([String userId = '']) =>
      StreakState(userId: userId);

  /// Parses a row of `streaks`.
  factory StreakState.fromJson(Map<String, dynamic> json) {
    final last = json['last_active_date'] as String?;
    return StreakState(
      userId: (json['user_id'] as String?) ?? '',
      current: (json['current'] as num?)?.toInt() ?? 0,
      longest: (json['longest'] as num?)?.toInt() ?? 0,
      lastActiveDate: last == null ? null : parseDayKey(last),
      xp: (json['xp'] as num?)?.toInt() ?? 0,
    );
  }

  /// Owner (`user_id`).
  final String userId;

  /// Streak length as stored (`current`). Use `StreakLogic.effectiveCurrent`
  /// for display, because a broken streak is only reset on the next activity.
  final int current;

  /// Best streak ever (`longest`).
  final int longest;

  /// Last local day with a workout or completed challenge.
  final DateTime? lastActiveDate;

  /// Total XP earned (`xp`).
  final int xp;

  /// Returns a copy with the given fields replaced.
  StreakState copyWith({
    String? userId,
    int? current,
    int? longest,
    DateTime? lastActiveDate,
    int? xp,
  }) {
    return StreakState(
      userId: userId ?? this.userId,
      current: current ?? this.current,
      longest: longest ?? this.longest,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      xp: xp ?? this.xp,
    );
  }

  /// Converts to a `streaks` row.
  Map<String, dynamic> toJson() {
    final last = lastActiveDate;
    return {
      'user_id': userId,
      'current': current,
      'longest': longest,
      'last_active_date': last == null ? null : dayKey(last),
      'xp': xp,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is StreakState &&
      other.userId == userId &&
      other.current == current &&
      other.longest == longest &&
      other.lastActiveDate == lastActiveDate &&
      other.xp == xp;

  @override
  int get hashCode => Object.hash(userId, current, longest, lastActiveDate, xp);
}
