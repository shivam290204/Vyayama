import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/data/workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/bodyweight_workout_flow.dart';
import 'package:fitbuddy/features/workouts/data/yoga_flow.dart';

/// Supabase implementation of [WorkoutRepository] backed by `workout_plans`,
/// `plan_days`, `plan_exercises`, and `exercises`. Falls back gracefully
/// to bundled assets if the database tables are empty or unreachable.
class SupabaseWorkoutRepository implements WorkoutRepository {
  SupabaseWorkoutRepository({
    SupabaseClient? client,
    AssetBundle? bundle,
  })  : _client = client ?? Supabase.instance.client,
        _bundle = bundle ?? rootBundle;

  static const exercisesAsset = 'assets/data/exercises.json';
  static const plansAsset = 'assets/data/workout_plans.json';

  final SupabaseClient _client;
  final AssetBundle _bundle;

  List<Exercise>? _assetExercises;
  List<WorkoutPlan>? _assetSystemPlans;

  Future<String?> _resolveUserId() async {
    try {
      final user = _client.auth.currentUser;
      if (user != null) return user.id;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('last_signed_in_user_id');
    } catch (_) {}
    return null;
  }

  String get _userId {
    final user = _client.auth.currentUser;
    if (user != null) return user.id;
    throw StateError('User not signed in');
  }

  Future<Map<String, dynamic>> _loadAsset(String path) async {
    final raw = await _bundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<Exercise>> _loadAssetExercises() async {
    if (_assetExercises != null) return _assetExercises!;
    final data = await _loadAsset(exercisesAsset);
    final list = <Exercise>[
      for (final j in data['exercises'] as List)
        Exercise.fromJson(j as Map<String, dynamic>),
    ];
    return _assetExercises = List.unmodifiable(list);
  }

  Future<List<WorkoutPlan>> _loadAssetPlans() async {
    if (_assetSystemPlans != null) return _assetSystemPlans!;
    final data = await _loadAsset(plansAsset);
    final list = <WorkoutPlan>[
      for (final j in data['plans'] as List)
        WorkoutPlan.fromJson(j as Map<String, dynamic>),
    ];
    return _assetSystemPlans = List.unmodifiable(list);
  }

  @override
  Future<List<Exercise>> getExercises() async {
    try {
      final res = await _client.from('exercises').select().order('name');
      if (res.isNotEmpty) {
        return (res as List)
            .map((r) => Exercise.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (_) {
      // Fallback to bundled asset
    }
    return _loadAssetExercises();
  }

  @override
  Future<List<WorkoutPlan>> getSystemPlans() async {
    try {
      final res = await _client
          .from('workout_plans')
          .select('*, days:plan_days(*, exercises:plan_exercises(*))')
          .eq('is_system', true);

      if (res.isNotEmpty) {
        return (res as List)
            .map((r) => WorkoutPlan.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      }
    } catch (_) {
      // Fallback to bundled asset
    }
    return _loadAssetPlans();
  }

  @override
  Future<List<WorkoutPlan>> getMyPlans() async {
    final uid = await _resolveUserId();
    if (uid != null && uid.isNotEmpty) {
      try {
        final res = await _client
            .from('workout_plans')
            .select('*, days:plan_days(*, exercises:plan_exercises(*))')
            .eq('is_system', false)
            .eq('owner_id', uid)
            .order('created_at', ascending: false);

        final plans = (res as List)
            .map((r) => WorkoutPlan.fromJson(Map<String, dynamic>.from(r)))
            .toList();

        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = jsonEncode([for (final p in plans) p.toJson()]);
          await prefs.setString('cached_my_plans_$uid', raw);
        } catch (_) {}

        return plans;
      } catch (_) {}
    }

    // Offline fallback: load from cached plans in SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = uid != null ? 'cached_my_plans_$uid' : null;
      String? raw;
      if (key != null) {
        raw = prefs.getString(key);
      }
      if (raw == null || raw.isEmpty) {
        for (final k in prefs.getKeys()) {
          if (k.startsWith('cached_my_plans_')) {
            raw = prefs.getString(k);
            if (raw != null && raw.isNotEmpty) break;
          }
        }
      }
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        return [
          for (final item in list)
            WorkoutPlan.fromJson(Map<String, dynamic>.from(item as Map)),
        ];
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<WorkoutPlan?> getPlan(String id) async {
    try {
      final res = await _client
          .from('workout_plans')
          .select('*, days:plan_days(*, exercises:plan_exercises(*))')
          .eq('id', id)
          .maybeSingle();

      if (res != null) {
        return WorkoutPlan.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (_) {}

    // Check custom plans cache fallback
    try {
      final myPlans = await getMyPlans();
      for (final p in myPlans) {
        if (p.id == id) return p;
      }
    } catch (_) {}

    // Check system plans fallback
    final fallback = await _loadAssetPlans();
    for (final p in fallback) {
      if (p.id == id) return p;
    }

    // Check BodyweightWorkoutCatalog fallback
    for (final flow in BodyweightWorkoutCatalog.workouts) {
      if (flow.id == id) return flow.toWorkoutPlan();
    }

    // Check YogaCatalog fallback
    for (final flow in YogaCatalog.flows) {
      if (flow.id == id) return flow.toWorkoutPlan();
    }
    return null;
  }

  @override
  Future<WorkoutPlan?> getPlanByDayId(String dayId) async {
    try {
      final dayRow = await _client
          .from('plan_days')
          .select('plan_id')
          .eq('id', dayId)
          .maybeSingle();

      if (dayRow != null && dayRow['plan_id'] != null) {
        return await getPlan(dayRow['plan_id'].toString());
      }
    } catch (_) {}

    // Check custom plans cache fallback
    try {
      final myPlans = await getMyPlans();
      for (final p in myPlans) {
        if (p.days.any((d) => d.id == dayId)) return p;
      }
    } catch (_) {}

    // Check system plans fallback
    final fallback = await _loadAssetPlans();
    for (final p in fallback) {
      if (p.days.any((d) => d.id == dayId)) return p;
    }

    // Check BodyweightWorkoutCatalog fallback
    for (final flow in BodyweightWorkoutCatalog.workouts) {
      final plan = flow.toWorkoutPlan();
      if (plan.days.any((d) => d.id == dayId)) return plan;
    }

    // Check YogaCatalog fallback
    for (final flow in YogaCatalog.flows) {
      final plan = flow.toWorkoutPlan();
      if (plan.days.any((d) => d.id == dayId)) return plan;
    }
    return null;
  }

  @override
  Future<WorkoutPlan> savePlan(WorkoutPlan plan) async {
    final isNew = plan.id.startsWith('draft_');

    // 1. Save workout_plan parent row
    final planPayload = <String, dynamic>{
      if (!isNew) 'id': plan.id,
      'title': plan.title.trim().isEmpty ? 'My Custom Plan' : plan.title.trim(),
      'goal': plan.goal,
      'level': plan.level,
      'is_system': false,
      'owner_id': _userId,
    };

    final savedPlanRow = await _client
        .from('workout_plans')
        .upsert(planPayload)
        .select()
        .single();

    final planId = savedPlanRow['id'].toString();

    // 2. Delete existing days if updating
    if (!isNew) {
      await _client.from('plan_days').delete().eq('plan_id', planId);
    }

    // 3. Insert days and exercises
    final savedDays = <PlanDay>[];
    for (final day in plan.days) {
      final dayRow = await _client
          .from('plan_days')
          .insert({
            'plan_id': planId,
            'day_number': day.dayNumber,
            'name': day.name,
          })
          .select()
          .single();

      final dayId = dayRow['id'].toString();

      final savedExercises = <PlanExercise>[];
      for (var i = 0; i < day.exercises.length; i++) {
        final ex = day.exercises[i];
        final exRow = await _client
            .from('plan_exercises')
            .insert({
              'plan_day_id': dayId,
              'exercise_id': ex.exerciseId,
              'sort_order': ex.sortOrder,
              'sets': ex.sets,
              'reps': ex.reps,
              'duration_sec': ex.durationSec,
              'rest_sec': ex.restSec,
            })
            .select()
            .single();

        savedExercises.add(PlanExercise.fromJson(Map<String, dynamic>.from(exRow)));
      }

      savedDays.add(PlanDay(
        id: dayId,
        dayNumber: day.dayNumber,
        name: day.name,
        exercises: savedExercises,
      ));
    }

    return WorkoutPlan(
      id: planId,
      title: savedPlanRow['title'] as String,
      goal: savedPlanRow['goal'] as String?,
      level: savedPlanRow['level'] as String?,
      isSystem: false,
      ownerId: _userId,
      days: savedDays,
    );
  }

  @override
  Future<void> deletePlan(String id) async {
    try {
      await _client
          .from('workout_plans')
          .delete()
          .eq('id', id)
          .eq('owner_id', _userId);
    } catch (_) {}
    final uid = await _resolveUserId();
    if (uid != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final myPlans = await getMyPlans();
        final filtered = myPlans.where((p) => p.id != id).toList();
        final raw = jsonEncode([for (final p in filtered) p.toJson()]);
        await prefs.setString('cached_my_plans_$uid', raw);
      } catch (_) {}
    }
  }
}
