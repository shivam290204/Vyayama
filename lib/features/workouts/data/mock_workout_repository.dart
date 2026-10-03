import 'dart:convert';

import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/data/workout_repository.dart';
import 'package:flutter/services.dart';

/// In-memory repository that reads the bundled JSON assets.
class MockWorkoutRepository implements WorkoutRepository {
  MockWorkoutRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const exercisesAsset = 'assets/data/exercises.json';
  static const plansAsset = 'assets/data/workout_plans.json';
  static const _mockOwnerId = 'mock-user';

  final AssetBundle _bundle;
  final List<WorkoutPlan> _mine = [];
  List<Exercise>? _exercises;
  List<WorkoutPlan>? _system;

  Future<Map<String, dynamic>> _load(String path) async {
    final raw = await _bundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<List<Exercise>> getExercises() async {
    final cached = _exercises;
    if (cached != null) return cached;
    final data = await _load(exercisesAsset);
    final list = <Exercise>[
      for (final j in data['exercises'] as List)
        Exercise.fromJson(j as Map<String, dynamic>),
    ];
    return _exercises = List.unmodifiable(list);
  }

  @override
  Future<List<WorkoutPlan>> getSystemPlans() async {
    final cached = _system;
    if (cached != null) return cached;
    final data = await _load(plansAsset);
    final list = <WorkoutPlan>[
      for (final j in data['plans'] as List)
        WorkoutPlan.fromJson(j as Map<String, dynamic>),
    ];
    return _system = List.unmodifiable(list);
  }

  @override
  Future<List<WorkoutPlan>> getMyPlans() async => List.unmodifiable(_mine);

  Future<List<WorkoutPlan>> _all() async =>
      [...await getSystemPlans(), ..._mine];

  @override
  Future<WorkoutPlan?> getPlan(String id) async {
    for (final p in await _all()) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<WorkoutPlan?> getPlanByDayId(String dayId) async {
    for (final p in await _all()) {
      if (p.days.any((d) => d.id == dayId)) return p;
    }
    return null;
  }

  @override
  Future<WorkoutPlan> savePlan(WorkoutPlan plan) async {
    final saved = plan.copyWith(
      isSystem: false,
      ownerId: plan.ownerId ?? _mockOwnerId,
    );
    final i = _mine.indexindexWhereId(saved.id);
    if (i >= 0) {
      _mine[i] = saved;
    } else {
      _mine.add(saved);
    }
    return saved;
  }

  @override
  Future<void> deletePlan(String id) async {
    _mine.removeWhere((p) => p.id == id);
  }
}

extension on List<WorkoutPlan> {
  int indexindexWhereId(String id) => indexWhere((p) => p.id == id);
}
