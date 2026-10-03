import 'package:fitbuddy/features/nutrition/data/meal.dart';
import 'package:flutter/foundation.dart';

/// One piece of general diet guidance from `diet_tips.json`.
@immutable
class DietTip {
  /// Creates a tip.
  const DietTip({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.goals = const <String>[],
    this.dietTypes = const <DietType>[],
    this.conditions = const <String>[],
  });

  /// Reads a tip from JSON.
  factory DietTip.fromJson(Map<String, dynamic> json) => DietTip(
        id: json['id'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        goals: _strings(json['goals']),
        dietTypes: _strings(json['diet_types'])
            .map(DietType.fromJson)
            .toList(growable: false),
        conditions: _strings(json['conditions']),
      );

  /// Category: eat_more, limit, general, hydration, sleep_eat, sleep_avoid.
  static const String eatMore = 'eat_more';

  /// Category for foods to limit.
  static const String limit = 'limit';

  /// Category for foods that help near sleep.
  static const String sleepEat = 'sleep_eat';

  /// Category for foods to avoid near sleep.
  static const String sleepAvoid = 'sleep_avoid';

  /// Unique id.
  final String id;

  /// Category name.
  final String category;

  /// Short title.
  final String title;

  /// One-sentence explanation.
  final String body;

  /// Goals this applies to (empty means all).
  final List<String> goals;

  /// Diet types this applies to (empty means all).
  final List<DietType> dietTypes;

  /// Condition keys this applies to (empty means everyone).
  final List<String> conditions;

  /// Writes the tip to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'category': category,
        'title': title,
        'body': body,
        'goals': goals,
        'diet_types': dietTypes.map((d) => d.json).toList(),
        'conditions': conditions,
      };
}

List<String> _strings(Object? value) =>
    (value as List<dynamic>?)?.map((e) => e.toString()).toList() ??
    const <String>[];
