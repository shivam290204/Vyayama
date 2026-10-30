import 'package:flutter/foundation.dart';

/// Semantic category of the fitness insight.
enum InsightCategory {
  /// Progress and volume within the current 7-day window.
  consistency,

  /// Active recovery, rest day, and overtraining cautions.
  recovery,

  /// Daily streak milestones, countdowns, and achievements.
  streak,

  /// Week-over-week comparisons in steps and movement volume.
  activityChange,

  /// Time-of-day habit formation and scheduling patterns.
  workoutPattern,

  /// Tailored advice based on goal, health profile, or weight trends.
  recommendation,
}

/// Priority tier determining insight ranking order.
enum InsightPriority {
  /// High urgency (e.g. overtraining warning, immediate recovery need).
  urgent(4),

  /// Major accomplishment or significant trend.
  high(3),

  /// Helpful progression observation or steady habit praise.
  medium(2),

  /// Subtle lifestyle observation or educational tip.
  low(1);

  const InsightPriority(this.weight);
  final int weight;
}

/// A deterministic, personalized fitness insight supported strictly by actual user data.
@immutable
class FitnessInsight {
  const FitnessInsight({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    required this.createdAt,
    this.actionLabel,
    this.actionRoute,
    this.supportingData = const {},
  });

  /// Unique identifier for deduplication or dismissal.
  final String id;

  /// Headline summarizing the finding in plain, encouraging language.
  final String title;

  /// Human-readable explanation grounded in user data facts.
  final String message;

  /// Category for icon, badge, and theming.
  final InsightCategory category;

  /// Priority for sorting and highlighting.
  final InsightPriority priority;

  /// Timestamp when this insight was evaluated.
  final DateTime createdAt;

  /// Optional label for a direct action (e.g. 'Start Workout', 'View Activity').
  final String? actionLabel;

  /// Optional app route path to navigate on action tap (e.g. '/workouts').
  final String? actionRoute;

  /// Underlying facts that justify this insight (never fabricated).
  final Map<String, dynamic> supportingData;

  FitnessInsight copyWith({
    String? id,
    String? title,
    String? message,
    InsightCategory? category,
    InsightPriority? priority,
    DateTime? createdAt,
    String? actionLabel,
    String? actionRoute,
    Map<String, dynamic>? supportingData,
  }) {
    return FitnessInsight(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      actionLabel: actionLabel ?? this.actionLabel,
      actionRoute: actionRoute ?? this.actionRoute,
      supportingData: supportingData ?? this.supportingData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitnessInsight &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          category == other.category &&
          priority == other.priority;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ category.hashCode ^ priority.hashCode;
}

