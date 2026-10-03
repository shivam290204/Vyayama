import 'package:flutter/foundation.dart';

/// Kind of challenge (column `challenges.type`).
enum ChallengeType {
  /// Steps walked today. Fed from daily stats.
  steps('steps', 'steps'),

  /// Active minutes today. Fed from daily stats.
  activeMinutes('active_minutes', 'minutes'),

  /// Repetitions of an exercise, counted by the user.
  reps('reps', 'reps'),

  /// Glasses of water, counted by the user.
  water('water', 'glasses'),

  /// Any small countable action (for example movement breaks).
  count('count', 'times'),

  /// Finish today's workout. Fed from the workout log.
  workout('workout', 'workout'),

  /// A single tick-box task.
  checkoff('checkoff', 'done');

  const ChallengeType(this.dbValue, this.unit);

  /// Value stored in the database and JSON.
  final String dbValue;

  /// Unit shown after the number, for example "glasses".
  final String unit;

  /// Parses a stored value, defaulting to [checkoff].
  static ChallengeType parse(String? value) => values.firstWhere(
        (t) => t.dbValue == value,
        orElse: () => ChallengeType.checkoff,
      );

  /// Whether progress comes from other data instead of user taps.
  bool get isAutoTracked =>
      this == steps || this == activeMinutes || this == workout;
}

/// A daily challenge. Mirrors table `challenges`.
@immutable
class Challenge {
  /// Creates a challenge.
  const Challenge({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    required this.targetValue,
    this.xp = 10,
  });

  /// Parses a row of `challenges` (or an entry of `challenges.json`).
  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      type: ChallengeType.parse(json['type'] as String?),
      targetValue: (json['target_value'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 10,
    );
  }

  /// Row id.
  final String id;

  /// Short title, for example "Do 20 squats".
  final String title;

  /// One or two friendly sentences.
  final String description;

  /// Kind of challenge.
  final ChallengeType type;

  /// Amount needed to complete it (`target_value`).
  final int targetValue;

  /// XP awarded on completion.
  final int xp;

  /// Whether [current] reaches the target.
  bool isCompleteAt(int current) => current >= targetValue;

  /// Progress from 0.0 to 1.0 for [current].
  double fractionFor(int current) {
    if (targetValue <= 0) return 1;
    return (current / targetValue).clamp(0.0, 1.0).toDouble();
  }

  /// Converts to a `challenges` row.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.dbValue,
        'target_value': targetValue,
        'xp': xp,
      };
}
