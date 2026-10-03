import 'dart:convert';

import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/data/meal.dart';
import 'package:fitbuddy/features/nutrition/data/nutrition_repository.dart';
import 'package:flutter/services.dart';

/// In-memory [NutritionRepository]; content comes from the asset bundle.
class MockNutritionRepository implements NutritionRepository {
  /// Creates the mock. Pass a [bundle] in tests.
  MockNutritionRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<DietTip>? _tips;
  List<Meal>? _meals;
  final Map<String, int> _water = <String, int>{};

  @override
  Future<List<DietTip>> loadDietTips() async {
    final cached = _tips;
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/data/diet_tips.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final tips = (decoded['tips'] as List<dynamic>)
        .map((e) => DietTip.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _tips = tips;
    return tips;
  }

  @override
  Future<List<Meal>> loadMeals() async {
    final cached = _meals;
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/data/meals.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final meals = (decoded['meals'] as List<dynamic>)
        .map((e) => Meal.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _meals = meals;
    return meals;
  }

  @override
  Future<int> getWaterGlasses(DateTime date) async => _water[_key(date)] ?? 0;

  @override
  Future<void> setWaterGlasses(DateTime date, int glasses) async {
    _water[_key(date)] = glasses;
  }

  String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
