import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';

/// One day of activity. Mirrors table `daily_stats`.
@immutable
class DailyStats {
  /// Creates the stats for [date].
  const DailyStats({
    this.id = '',
    this.userId = '',
    required this.date,
    this.steps = 0,
    this.calories = 0,
    this.activeMinutes = 0,
  });

  /// A day with nothing recorded.
  factory DailyStats.empty(DateTime date, {String userId = ''}) =>
      DailyStats(userId: userId, date: dayOnly(date));

  /// Parses a row of `daily_stats`.
  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      date: parseDayKey(json['date'] as String),
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      activeMinutes: (json['active_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Row id, empty when not saved yet.
  final String id;

  /// Owner (`user_id`).
  final String userId;

  /// Local calendar day (`date`).
  final DateTime date;

  /// Steps walked (`steps`).
  final int steps;

  /// Active calories burned (`calories`). 0 means "not measured".
  final int calories;

  /// Active minutes (`active_minutes`).
  final int activeMinutes;

  /// True when nothing was recorded.
  bool get isEmpty => steps == 0 && calories == 0 && activeMinutes == 0;

  /// Returns a copy with the given fields replaced.
  DailyStats copyWith({
    String? id,
    String? userId,
    DateTime? date,
    int? steps,
    int? calories,
    int? activeMinutes,
  }) {
    return DailyStats(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
      activeMinutes: activeMinutes ?? this.activeMinutes,
    );
  }

  /// Converts to a `daily_stats` row.
  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        if (userId.isNotEmpty) 'user_id': userId,
        'date': dayKey(date),
        'steps': steps,
        'calories': calories,
        'active_minutes': activeMinutes,
      };
}
