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
  })  : _client = client ?? _safeClient(),
        _bundle = bundle ?? rootBundle;

  static SupabaseClient? _safeClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static const exercisesAsset = 'assets/data/exercises.json';
  static const plansAsset = 'assets/data/workout_plans.json';

  final SupabaseClient? _client;
  final AssetBundle _bundle;

  List<Exercise>? _assetExercises;
  List<WorkoutPlan>? _assetSystemPlans;

  Future<String?> _resolveUserId() async {
    try {
      final user = _client?.auth.currentUser;
      if (user != null) return user.id;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('last_signed_in_user_id');
    } catch (_) {}
    return null;
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
    final client = _client;
    if (client != null) {
      try {
        final res = await client.from('exercises').select().order('name');
        if (res.isNotEmpty) {
          return (res as List)
              .map((r) => Exercise.fromJson(Map<String, dynamic>.from(r)))
              .toList();
        }
      } catch (_) {
        // Fallback to bundled asset
      }
    }
    return _loadAssetExercises();
  }

  @override
  Future<List<WorkoutPlan>> getSystemPlans() async {
    final client = _client;
    if (client != null) {
      try {
        final res = await client
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
    }
    return _loadAssetPlans();
  }

  @override
  Future<List<WorkoutPlan>> getMyPlans() async {
    final uid = await _resolveUserId();
    final client = _client;
    if (client != null && uid != null && uid.isNotEmpty) {
      await _syncPendingPlans(uid);

      try {
        final res = await client
            .from('workout_plans')
            .select('*, days:plan_days(*, exercises:plan_exercises(*))')
            .eq('is_system', false)
            .eq('owner_id', uid)
            .order('created_at', ascending: false);

        final plans = (res as List)
            .map((r) => WorkoutPlan.fromJson(Map<String, dynamic>.from(r)))
            .toList();

        // Retain any pending offline plans that haven't synced yet
        final prefs = await SharedPreferences.getInstance();
        final syncQueueKey = 'pending_sync_workout_plans_$uid';
        final pendingIds = prefs.getStringList(syncQueueKey) ?? [];
        if (pendingIds.isNotEmpty) {
          final cachedRaw = prefs.getString('cached_my_plans_$uid');
          if (cachedRaw != null && cachedRaw.isNotEmpty) {
            final cachedList = (jsonDecode(cachedRaw) as List)
                .map((m) => WorkoutPlan.fromJson(Map<String, dynamic>.from(m as Map)));
            for (final cp in cachedList) {
              if (pendingIds.contains(cp.id) && !plans.any((p) => p.id == cp.id)) {
                plans.insert(0, cp);
              }
            }
          }
        }

        try {
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
    final client = _client;
    if (client != null) {
      try {
        final res = await client
            .from('workout_plans')
            .select('*, days:plan_days(*, exercises:plan_exercises(*))')
            .eq('id', id)
            .maybeSingle();

        if (res != null) {
          return WorkoutPlan.fromJson(Map<String, dynamic>.from(res));
        }
      } catch (_) {}
    }

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
    final client = _client;
    if (client != null) {
      try {
        final dayRow = await client
            .from('plan_days')
            .select('plan_id')
            .eq('id', dayId)
            .maybeSingle();

        if (dayRow != null && dayRow['plan_id'] != null) {
          return await getPlan(dayRow['plan_id'].toString());
        }
      } catch (_) {}
    }

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
    final uid = await _resolveUserId();
    final isNew = plan.id.isEmpty || plan.id.startsWith('draft_');
    final planTitle = plan.title.trim().isEmpty ? 'My Custom Plan' : plan.title.trim();

    // 1. Attempt cloud save if user is signed in
    final client = _client;
    if (client != null && uid != null && uid.isNotEmpty) {
      try {
        final planPayload = <String, dynamic>{
          if (!isNew) 'id': plan.id,
          'title': planTitle,
          'goal': plan.goal,
          'level': plan.level,
          'is_system': false,
          'owner_id': uid,
        };

        final savedPlanRow = await client
            .from('workout_plans')
            .upsert(planPayload)
            .select()
            .single();

        final planId = savedPlanRow['id'].toString();

        if (!isNew) {
          await client.from('plan_days').delete().eq('plan_id', planId);
        }

        final savedDays = <PlanDay>[];
        for (final day in plan.days) {
          final dayRow = await client
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
            final exRow = await client
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

        final savedOnlinePlan = WorkoutPlan(
          id: planId,
          title: savedPlanRow['title'] as String,
          goal: savedPlanRow['goal'] as String?,
          level: savedPlanRow['level'] as String?,
          isSystem: false,
          ownerId: uid,
          days: savedDays,
        );

        await _cacheLocalPlan(savedOnlinePlan, uid: uid, removePendingSyncId: plan.id);
        return savedOnlinePlan;
      } catch (_) {
        // Fall through to offline cache handling
      }
    }

    // 2. Offline fallback: Generate local IDs and persist locally
    final localPlanId = isNew ? 'local_${DateTime.now().millisecondsSinceEpoch}' : plan.id;
    final localDays = <PlanDay>[];
    for (var dIdx = 0; dIdx < plan.days.length; dIdx++) {
      final day = plan.days[dIdx];
      final dayId = (day.id.isEmpty || day.id.startsWith('draft_'))
          ? '${localPlanId}_d${day.dayNumber}'
          : day.id;

      final localExercises = <PlanExercise>[];
      for (var eIdx = 0; eIdx < day.exercises.length; eIdx++) {
        final ex = day.exercises[eIdx];
        final exId = (ex.id.isEmpty || ex.id.startsWith('draft_'))
            ? '${dayId}_ex$eIdx'
            : ex.id;
        localExercises.add(PlanExercise(
          id: exId,
          exerciseId: ex.exerciseId,
          sortOrder: ex.sortOrder,
          sets: ex.sets,
          reps: ex.reps,
          durationSec: ex.durationSec,
          restSec: ex.restSec,
        ));
      }

      localDays.add(PlanDay(
        id: dayId,
        dayNumber: day.dayNumber,
        name: day.name,
        exercises: localExercises,
      ));
    }

    final localPlan = WorkoutPlan(
      id: localPlanId,
      title: planTitle,
      goal: plan.goal,
      level: plan.level,
      isSystem: false,
      ownerId: uid,
      days: localDays,
    );

    await _cacheLocalPlan(localPlan, uid: uid, markPendingSync: true);
    return localPlan;
  }

  Future<void> _cacheLocalPlan(
    WorkoutPlan plan, {
    String? uid,
    bool markPendingSync = false,
    String? removePendingSyncId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = uid != null ? 'cached_my_plans_$uid' : 'cached_my_plans_default';
      
      List<WorkoutPlan> cachedPlans = [];
      final raw = prefs.getString(cacheKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final list = jsonDecode(raw) as List;
          cachedPlans = [
            for (final item in list)
              WorkoutPlan.fromJson(Map<String, dynamic>.from(item as Map)),
          ];
        } catch (_) {}
      }

      final existingIndex = cachedPlans.indexWhere(
        (p) => p.id == plan.id || (removePendingSyncId != null && p.id == removePendingSyncId),
      );
      if (existingIndex >= 0) {
        cachedPlans[existingIndex] = plan;
      } else {
        cachedPlans.insert(0, plan);
      }

      await prefs.setString(
        cacheKey,
        jsonEncode([for (final p in cachedPlans) p.toJson()]),
      );

      final syncQueueKey = uid != null ? 'pending_sync_workout_plans_$uid' : 'pending_sync_workout_plans_default';
      final pendingIds = prefs.getStringList(syncQueueKey) ?? [];

      if (removePendingSyncId != null) {
        pendingIds.remove(removePendingSyncId);
      }

      if (markPendingSync) {
        if (!pendingIds.contains(plan.id)) {
          pendingIds.add(plan.id);
        }
      } else {
        pendingIds.remove(plan.id);
      }
      await prefs.setStringList(syncQueueKey, pendingIds);
    } catch (_) {}
  }

  Future<void> _syncPendingPlans(String uid) async {
    final client = _client;
    if (client == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncQueueKey = 'pending_sync_workout_plans_$uid';
      final pendingIds = prefs.getStringList(syncQueueKey) ?? [];
      if (pendingIds.isEmpty) return;

      final cacheKey = 'cached_my_plans_$uid';
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return;

      final cachedList = (jsonDecode(raw) as List)
          .map((m) => WorkoutPlan.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList();

      for (final planId in List<String>.from(pendingIds)) {
        final plan = cachedList.firstWhere(
          (p) => p.id == planId,
          orElse: () => const WorkoutPlan(id: '', title: '', days: []),
        );
        if (plan.id.isEmpty) {
          pendingIds.remove(planId);
          continue;
        }

        try {
          final isNew = plan.id.startsWith('draft_') || plan.id.startsWith('local_');
          final planPayload = <String, dynamic>{
            if (!isNew) 'id': plan.id,
            'title': plan.title,
            'goal': plan.goal,
            'level': plan.level,
            'is_system': false,
            'owner_id': uid,
          };

          final savedPlanRow = await client
              .from('workout_plans')
              .upsert(planPayload)
              .select()
              .single();

          final remotePlanId = savedPlanRow['id'].toString();

          if (!isNew) {
            await client.from('plan_days').delete().eq('plan_id', remotePlanId);
          }

          for (final day in plan.days) {
            final dayRow = await client
                .from('plan_days')
                .insert({
                  'plan_id': remotePlanId,
                  'day_number': day.dayNumber,
                  'name': day.name,
                })
                .select()
                .single();

            final dayId = dayRow['id'].toString();

            for (final ex in day.exercises) {
              await client.from('plan_exercises').insert({
                'plan_day_id': dayId,
                'exercise_id': ex.exerciseId,
                'sort_order': ex.sortOrder,
                'sets': ex.sets,
                'reps': ex.reps,
                'duration_sec': ex.durationSec,
                'rest_sec': ex.restSec,
              });
            }
          }

          pendingIds.remove(planId);
          if (plan.id.startsWith('local_')) {
            final idx = cachedList.indexWhere((p) => p.id == planId);
            if (idx >= 0) {
              cachedList[idx] = plan.copyWith(id: remotePlanId);
            }
          }
        } catch (_) {
          break;
        }
      }

      await prefs.setStringList(syncQueueKey, pendingIds);
      await prefs.setString(cacheKey, jsonEncode([for (final p in cachedList) p.toJson()]));
    } catch (_) {}
  }

  @override
  Future<void> deletePlan(String id) async {
    final uid = await _resolveUserId();
    final client = _client;
    if (client != null && uid != null && uid.isNotEmpty) {
      try {
        await client
            .from('workout_plans')
            .delete()
            .eq('id', id)
            .eq('owner_id', uid);
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = uid != null ? 'cached_my_plans_$uid' : null;
      if (key != null) {
        final raw = prefs.getString(key);
        if (raw != null && raw.isNotEmpty) {
          final list = (jsonDecode(raw) as List)
              .map((m) => WorkoutPlan.fromJson(Map<String, dynamic>.from(m as Map)))
              .where((p) => p.id != id)
              .toList();
          await prefs.setString(key, jsonEncode([for (final p in list) p.toJson()]));
        }
        final syncQueueKey = 'pending_sync_workout_plans_$uid';
        final pendingIds = prefs.getStringList(syncQueueKey) ?? [];
        if (pendingIds.remove(id)) {
          await prefs.setStringList(syncQueueKey, pendingIds);
        }
      }
    } catch (_) {}
  }
}
