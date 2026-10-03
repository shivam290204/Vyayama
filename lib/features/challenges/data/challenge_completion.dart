import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';

/// One completed daily challenge. Mirrors table `challenge_completions`.
@immutable
class ChallengeCompletion {
  /// Creates a completion.
  const ChallengeCompletion({
    required this.id,
    required this.userId,
    required this.challengeId,
    required this.date,
  });

  /// Parses a row of `challenge_completions`.
  factory ChallengeCompletion.fromJson(Map<String, dynamic> json) {
    return ChallengeCompletion(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      challengeId: json['challenge_id'] as String,
      date: parseDayKey(json['date'] as String),
    );
  }

  /// Row id.
  final String id;

  /// Owner (`user_id`).
  final String userId;

  /// Challenge that was completed (`challenge_id`).
  final String challengeId;

  /// Local calendar day it was completed (`date`).
  final DateTime date;

  /// Converts to a `challenge_completions` row.
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'challenge_id': challengeId,
        'date': dayKey(date),
      };
}
