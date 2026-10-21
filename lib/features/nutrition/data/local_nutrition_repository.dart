import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/data/meal.dart';
import 'package:fitbuddy/features/nutrition/data/nutrition_repository.dart';

/// Persistent [NutritionRepository] storing water logs and meal preferences
/// in local [SharedPreferences] for complete offline operation.
class LocalNutritionRepository implements NutritionRepository {
  LocalNutritionRepository({
    required SharedPreferences prefs,
    AssetBundle? bundle,
  })  : _prefs = prefs,
        _bundle = bundle ?? rootBundle;

  final SharedPreferences _prefs;
  final AssetBundle _bundle;

  List<DietTip>? _cachedTips;
  List<Meal>? _cachedMeals;

  static const String _waterKeyPrefix = 'nutrition_water_';
  static const String _dietTypeKey = 'nutrition_diet_type';
  static const String _activityLevelKey = 'nutrition_activity_level';
  static const String _conditionFriendlyKey = 'nutrition_condition_friendly';

  @override
  Future<List<DietTip>> loadDietTips() async {
    final cached = _cachedTips;
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/data/diet_tips.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final tips = (decoded['tips'] as List<dynamic>)
        .map((e) => DietTip.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _cachedTips = tips;
    return tips;
  }

  @override
  Future<List<Meal>> loadMeals() async {
    final cached = _cachedMeals;
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/data/meals.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final meals = (decoded['meals'] as List<dynamic>)
        .map((e) => Meal.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _cachedMeals = meals;
    return meals;
  }

  @override
  Future<int> getWaterGlasses(DateTime date) async {
    return _prefs.getInt('$_waterKeyPrefix${_key(date)}') ?? 0;
  }

  @override
  Future<void> setWaterGlasses(DateTime date, int glasses) async {
    await _prefs.setInt('$_waterKeyPrefix${_key(date)}', glasses);
  }

  /// Stored diet type preference (e.g., 'veg', 'vegan', 'non_veg').
  String? getSavedDietType() => _prefs.getString(_dietTypeKey);

  /// Saves diet type preference.
  Future<void> saveDietType(String dietType) =>
      _prefs.setString(_dietTypeKey, dietType);

  /// Stored activity level preference.
  String? getSavedActivityLevel() => _prefs.getString(_activityLevelKey);

  /// Saves activity level preference.
  Future<void> saveActivityLevel(String level) =>
      _prefs.setString(_activityLevelKey, level);

  /// Stored condition friendly filter toggle.
  bool? getSavedConditionFriendly() => _prefs.getBool(_conditionFriendlyKey);

  /// Saves condition friendly filter toggle.
  Future<void> saveConditionFriendly(bool value) =>
      _prefs.setBool(_conditionFriendlyKey, value);

  String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
