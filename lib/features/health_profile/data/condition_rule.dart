import 'package:flutter/foundation.dart';

/// Rules for one health condition, loaded from `conditions.json`.
@immutable
class ConditionRule {
  /// Creates a rule.
  const ConditionRule({
    required this.key,
    required this.label,
    this.description = '',
    this.avoidExerciseTags = const <String>[],
    this.safeAlternatives = const <String>[],
    this.notes = '',
  });

  /// Reads a rule from JSON.
  factory ConditionRule.fromJson(Map<String, dynamic> json) => ConditionRule(
        key: json['key'] as String,
        label: json['label'] as String,
        description: (json['description'] as String?) ?? '',
        avoidExerciseTags: _strings(json['avoid_exercise_tags']),
        safeAlternatives: _strings(json['safe_alternatives']),
        notes: (json['notes'] as String?) ?? '',
      );

  /// Stable key stored in `user_conditions.condition_key`.
  final String key;

  /// Friendly name.
  final String label;

  /// Short description.
  final String description;

  /// Exercise contraindication tags to avoid.
  final List<String> avoidExerciseTags;

  /// General, gentler options to explore.
  final List<String> safeAlternatives;

  /// General note (never medical advice).
  final String notes;

  /// Writes the rule to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'label': label,
        'description': description,
        'avoid_exercise_tags': avoidExerciseTags,
        'safe_alternatives': safeAlternatives,
        'notes': notes,
      };
}

List<String> _strings(Object? value) =>
    (value as List<dynamic>?)?.map((e) => e.toString()).toList() ??
    const <String>[];
