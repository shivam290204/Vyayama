import 'package:flutter/foundation.dart';

/// 3-tier user exertion rating prompt submitted post-workout.
enum WorkoutDifficultyRating {
  tooEasy('too_easy', 'Too Easy', 6.0),
  justRight('just_right', 'Just Right', 7.5),
  tooHard('too_hard', 'Too Hard', 9.5);

  const WorkoutDifficultyRating(this.id, this.label, this.estimatedRpe);

  final String id;
  final String label;

  /// Approximate RPE scale value (1 to 10) for feeding progression and adherence models.
  final double estimatedRpe;

  static WorkoutDifficultyRating fromId(String id) {
    return WorkoutDifficultyRating.values.firstWhere(
      (r) => r.id.toLowerCase() == id.toLowerCase(),
      orElse: () => WorkoutDifficultyRating.justRight,
    );
  }
}

/// Recorded post-workout difficulty feedback entry.
@immutable
class WorkoutDifficultyFeedback {
  const WorkoutDifficultyFeedback({
    required this.id,
    required this.userId,
    required this.planDayId,
    required this.completedAt,
    required this.rating,
    this.workoutLogId,
    required this.createdAt,
  });

  factory WorkoutDifficultyFeedback.fromJson(Map<String, dynamic> json) {
    return WorkoutDifficultyFeedback(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? 'local_user',
      planDayId: json['plan_day_id']?.toString() ?? '',
      completedAt: DateTime.parse(json['completed_at'] as String),
      rating: WorkoutDifficultyRating.fromId(json['rating']?.toString() ?? 'just_right'),
      workoutLogId: json['workout_log_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String planDayId;
  final DateTime completedAt;
  final WorkoutDifficultyRating rating;
  final String? workoutLogId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'plan_day_id': planDayId,
        'completed_at': completedAt.toUtc().toIso8601String(),
        'rating': rating.id,
        'workout_log_id': workoutLogId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

