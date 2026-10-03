import 'package:flutter/foundation.dart';

/// A completed workout (table `workout_logs`).
@immutable
class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.userId,
    required this.planDayId,
    required this.completedAt,
    required this.durationMin,
    required this.caloriesBurned,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      planDayId: json['plan_day_id']?.toString() ?? '',
      completedAt: DateTime.parse(json['completed_at'] as String),
      durationMin: (json['duration_min'] as num?)?.toInt() ?? 0,
      caloriesBurned: (json['calories_burned'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String userId;
  final String planDayId;
  final DateTime completedAt;
  final int durationMin;
  final int caloriesBurned;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'plan_day_id': planDayId,
        'completed_at': completedAt.toUtc().toIso8601String(),
        'duration_min': durationMin,
        'calories_burned': caloriesBurned,
      };
}
