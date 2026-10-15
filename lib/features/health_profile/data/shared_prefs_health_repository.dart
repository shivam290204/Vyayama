import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/health_profile/data/condition_rule.dart';
import 'package:fitbuddy/features/health_profile/data/health_repository.dart';
import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';

/// Persistent local storage implementation of [HealthRepository] backed by
/// [SharedPreferences].
class SharedPrefsHealthRepository implements HealthRepository {
  /// Creates the repository.
  SharedPrefsHealthRepository(this._prefs, {AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const String _kConditionsKey = 'vyayama_health_selected_conditions';
  static const String _kMedicinesKey = 'vyayama_health_medicines_list';
  static const String _kMealRemindersKey = 'vyayama_health_meal_reminders';

  final SharedPreferences _prefs;
  final AssetBundle _bundle;
  List<ConditionRule>? _cachedRules;

  @override
  Future<List<ConditionRule>> loadConditionRules() async {
    final cached = _cachedRules;
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/data/conditions.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rules = (decoded['conditions'] as List<dynamic>)
        .map((e) => ConditionRule.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _cachedRules = rules;
    return rules;
  }

  @override
  Future<List<String>> getSelectedConditionKeys() async {
    final list = _prefs.getStringList(_kConditionsKey);
    return list != null ? List<String>.unmodifiable(list) : const <String>[];
  }

  @override
  Future<void> saveSelectedConditionKeys(List<String> keys) async {
    await _prefs.setStringList(_kConditionsKey, keys);
  }

  @override
  Future<List<Medicine>> listMedicines() async {
    final rawList = _prefs.getStringList(_kMedicinesKey);
    if (rawList == null || rawList.isEmpty) return const <Medicine>[];
    final result = <Medicine>[];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        result.add(Medicine.fromJson(map));
      } catch (_) {}
    }
    return List<Medicine>.unmodifiable(result);
  }

  @override
  Future<Medicine> saveMedicine(Medicine medicine) async {
    final current = (await listMedicines()).toList();
    final toSave = medicine.id.isEmpty
        ? medicine.copyWith(
            id: 'med_${DateTime.now().millisecondsSinceEpoch}',
          )
        : medicine;

    final index = current.indexWhere((m) => m.id == toSave.id);
    if (index >= 0) {
      current[index] = toSave;
    } else {
      current.add(toSave);
    }

    final rawList = current.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs.setStringList(_kMedicinesKey, rawList);
    return toSave;
  }

  @override
  Future<void> deleteMedicine(String id) async {
    final current = (await listMedicines()).toList();
    current.removeWhere((m) => m.id == id);
    final rawList = current.map((m) => jsonEncode(m.toJson())).toList();
    await _prefs.setStringList(_kMedicinesKey, rawList);
  }

  @override
  Future<MealReminderSettings> getMealReminders() async {
    final raw = _prefs.getString(_kMealRemindersKey);
    if (raw == null) return MealReminderSettings.defaults();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return MealReminderSettings.fromJson(decoded);
    } catch (_) {
      return MealReminderSettings.defaults();
    }
  }

  @override
  Future<void> saveMealReminders(MealReminderSettings settings) async {
    await _prefs.setString(_kMealRemindersKey, jsonEncode(settings.toJson()));
  }
}
