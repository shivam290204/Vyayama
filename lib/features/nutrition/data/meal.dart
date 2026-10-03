import 'package:flutter/foundation.dart';

/// Diet type of a meal or a user.
enum DietType {
  /// Vegetarian (dairy allowed, no egg, meat or fish).
  veg('veg', 'Veg'),

  /// Includes eggs, fish and meat.
  nonVeg('non_veg', 'Non-veg'),

  /// No animal products.
  vegan('vegan', 'Vegan');

  const DietType(this.json, this.label);

  /// Value used in JSON.
  final String json;

  /// Friendly label.
  final String label;

  /// Parses a JSON value such as `non_veg`.
  static DietType fromJson(String value) {
    for (final type in values) {
      if (type.json == value) return type;
    }
    throw FormatException('Unknown diet type: $value');
  }
}

/// Which meal of the day a dish suits.
enum MealType {
  /// Morning.
  breakfast('Breakfast'),

  /// Midday.
  lunch('Lunch'),

  /// Between meals.
  snack('Snack'),

  /// Evening.
  dinner('Dinner');

  const MealType(this.label);

  /// Friendly label.
  final String label;
}

/// A suggested meal from `meals.json`. Calories are approximate.
@immutable
class Meal {
  /// Creates a meal.
  const Meal({
    required this.id,
    required this.name,
    required this.mealType,
    required this.dietType,
    required this.goals,
    required this.calories,
    required this.proteinG,
    this.cuisine = 'global',
    this.description = '',
    this.conditionFriendly = const <String>[],
  });

  /// Reads a meal from JSON.
  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: json['id'] as String,
        name: json['name'] as String,
        mealType: MealType.values.byName(json['meal_type'] as String),
        dietType: DietType.fromJson(json['diet_type'] as String),
        goals: _strings(json['goals']),
        calories: (json['calories'] as num).toInt(),
        proteinG: (json['protein_g'] as num).toInt(),
        cuisine: (json['cuisine'] as String?) ?? 'global',
        description: (json['description'] as String?) ?? '',
        conditionFriendly: _strings(json['condition_friendly']),
      );

  /// Unique id.
  final String id;

  /// Dish name.
  final String name;

  /// Meal of the day.
  final MealType mealType;

  /// Diet type.
  final DietType dietType;

  /// Goals this meal suits (`lose`, `gain`, `maintain`).
  final List<String> goals;

  /// Approximate calories.
  final int calories;

  /// Approximate protein in grams.
  final int proteinG;

  /// `indian` or `global`.
  final String cuisine;

  /// One-line description.
  final String description;

  /// Condition keys this meal is generally suited to.
  final List<String> conditionFriendly;

  /// Writes the meal to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'meal_type': mealType.name,
        'diet_type': dietType.json,
        'goals': goals,
        'calories': calories,
        'protein_g': proteinG,
        'cuisine': cuisine,
        'description': description,
        'condition_friendly': conditionFriendly,
      };
}

List<String> _strings(Object? value) =>
    (value as List<dynamic>?)?.map((e) => e.toString()).toList() ??
    const <String>[];
