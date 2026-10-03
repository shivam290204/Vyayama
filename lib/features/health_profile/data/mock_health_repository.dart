import 'dart:convert';

import 'package:fitbuddy/features/health_profile/data/condition_rule.dart';
import 'package:fitbuddy/features/health_profile/data/health_repository.dart';
import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:flutter/services.dart';

/// In-memory [HealthRepository]. Condition rules come from the asset bundle.
class MockHealthRepository implements HealthRepository {
  /// Creates the mock. Pass a [bundle] in tests.
  MockHealthRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<ConditionRule>? _rules;
  List<String> _selected = <String>[];
  final List<Medicine> _medicines = <Medicine>[];
  MealReminderSettings _meals = MealReminderSettings.defaults();
  int _nextId = 1;

  @override
  Future<List<ConditionRule>> loadConditionRules() async {
    final cached = _rules;
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/data/conditions.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rules = (decoded['conditions'] as List<dynamic>)
        .map((e) => ConditionRule.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    _rules = rules;
    return rules;
  }

  @override
  Future<List<String>> getSelectedConditionKeys() async =>
      List<String>.unmodifiable(_selected);

  @override
  Future<void> saveSelectedConditionKeys(List<String> keys) async {
    _selected = List<String>.of(keys);
  }

  @override
  Future<List<Medicine>> listMedicines() async =>
      List<Medicine>.unmodifiable(_medicines);

  @override
  Future<Medicine> saveMedicine(Medicine medicine) async {
    if (medicine.id.isEmpty) {
      final created = medicine.copyWith(id: 'med_${_nextId++}');
      _medicines.add(created);
      return created;
    }
    final index = _medicines.indexWhere((m) => m.id == medicine.id);
    if (index == -1) {
      _medicines.add(medicine);
    } else {
      _medicines[index] = medicine;
    }
    return medicine;
  }

  @override
  Future<void> deleteMedicine(String id) async {
    _medicines.removeWhere((m) => m.id == id);
  }

  @override
  Future<MealReminderSettings> getMealReminders() async => _meals;

  @override
  Future<void> saveMealReminders(MealReminderSettings settings) async {
    _meals = settings;
  }
}
