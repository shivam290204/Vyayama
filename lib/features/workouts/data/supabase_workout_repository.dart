import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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
  static const Duration _remoteTimeout = Duration(seconds: 4);

  final SupabaseClient? _client;
  final AssetBundle _bundle;

  List<Exercise>? _assetExercises;
  List<WorkoutPlan>? _assetSystemPlans;

  static const _uuid = Uuid();
  final Map<String, String> _catalogToDbUuid = {};
  final Map<String, String> _dbUuidToCatalog = {};
  final Set<String> _inFlightPlanSaves = {};
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  bool _isUuid(String s) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(s);

  String _deterministicUuid(String input) {
    if (_isUuid(input)) return input;
    return _uuid.v5(Namespace.url.value, input);
  }

  String resolveExerciseUuid(String exId) {
    if (_isUuid(exId)) return exId;
    if (_catalogToDbUuid.containsKey(exId)) {
      return _catalogToDbUuid[exId]!;
    }
    final mapped = _deterministicUuid(exId);
    _catalogToDbUuid[exId] = mapped;
    _dbUuidToCatalog[mapped] = exId;
    return mapped;
  }

  String resolveExerciseCatalogId(String exId) {
    if (_dbUuidToCatalog.containsKey(exId)) {
      return _dbUuidToCatalog[exId]!;
    }
    return exId;
  }

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
    try {
      final data = await _loadAsset(exercisesAsset);
      final list = <Exercise>[
        for (final j in data['exercises'] as List)
          Exercise.fromJson(j as Map<String, dynamic>),
      ];
      for (final ex in list) {
        final dbUuid = resolveExerciseUuid(ex.id);
        _catalogToDbUuid[ex.id] = dbUuid;
        _dbUuidToCatalog[dbUuid] = ex.id;
      }
      return _assetExercises = List.unmodifiable(list);
    } catch (_) {
      return _assetExercises = const [];
    }
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
        final res = await client
            .from('exercises')
            .select()
            .order('name')
            .timeout(_remoteTimeout);
        if (res.isNotEmpty) {
          for (final r in res) {
            final dbId = r['id']?.toString();
            final catId = r['catalog_id']?.toString() ?? dbId;
            if (dbId != null && catId != null) {
              _catalogToDbUuid[catId] = dbId;
              _dbUuidToCatalog[dbId] = catId;
            }
          }
          return (res as List).map((r) {
            final map = Map<String, dynamic>.from(r);
            if (map['catalog_id'] != null) {
              map['id'] = map['catalog_id'];
            }
            return Exercise.fromJson(map);
          }).toList();
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
            .eq('is_system', true)
            .timeout(_remoteTimeout);

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
      try {
        await _syncPendingPlans(uid).timeout(_remoteTimeout);
      } catch (_) {}

      try {
        final res = await client
            .from('workout_plans')
            .select('*, days:plan_days(*, exercises:plan_exercises(*, exercise:exercises(id, catalog_id)))')
            .eq('is_system', false)
            .eq('owner_id', uid)
            .order('created_at', ascending: false)
            .timeout(_remoteTimeout);

        if (_catalogToDbUuid.isEmpty) {
          await _loadAssetExercises();
        }

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
              final mappedId = _isUuid(cp.id) ? cp.id : _deterministicUuid(cp.id);
              if (pendingIds.contains(cp.id) &&
                  !plans.any((p) => p.id == cp.id || p.id == mappedId)) {
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
        final targetId = _isUuid(id) ? id : _deterministicUuid(id);
        final res = await client
            .from('workout_plans')
            .select('*, days:plan_days(*, exercises:plan_exercises(*, exercise:exercises(id, catalog_id)))')
            .eq('id', targetId)
            .maybeSingle()
            .timeout(_remoteTimeout);

        if (res != null) {
          return WorkoutPlan.fromJson(Map<String, dynamic>.from(res));
        }
      } catch (_) {}
    }

    // Check custom plans cache fallback
    try {
      final myPlans = await getMyPlans();
      for (final p in myPlans) {
        if (p.id == id || p.id == _deterministicUuid(id)) return p;
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
            .maybeSingle()
            .timeout(_remoteTimeout);

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
    if (_inFlightPlanSaves.contains(plan.id)) {
      return plan;
    }
    _inFlightPlanSaves.add(plan.id);

    try {
      final uid = await _resolveUserId();
      final stablePlanId = _isUuid(plan.id)
          ? plan.id
          : _deterministicUuid(plan.id.isNotEmpty ? plan.id : _uuid.v4());
      final planTitle =
          plan.title.trim().isEmpty ? 'My Custom Plan' : plan.title.trim();

      if (_catalogToDbUuid.isEmpty) {
        await _loadAssetExercises();
      }

      // 1. Attempt atomic cloud save if user is signed in
      final client = _client;
      if (client != null && uid != null && uid.isNotEmpty) {
        try {
          final planPayload = <String, dynamic>{
            'id': stablePlanId,
            'title': planTitle,
            'goal': plan.goal,
            'level': plan.level,
            'is_system': false,
            'owner_id': uid,
            'days': [
              for (final day in plan.days)
                {
                  if (_isUuid(day.id)) 'id': day.id,
                  'day_number': day.dayNumber,
                  'name': day.name,
                  'exercises': [
                    for (final ex in day.exercises)
                      {
                        if (_isUuid(ex.id)) 'id': ex.id,
                        'exercise_id': resolveExerciseUuid(ex.exerciseId),
                        'sort_order': ex.sortOrder,
                        'sets': ex.sets,
                        'reps': ex.reps,
                        'duration_sec': ex.durationSec,
                        'rest_sec': ex.restSec,
                      },
                  ],
                },
            ],
          };

          await client
              .rpc('save_workout_plan', params: {'p_plan': planPayload})
              .timeout(const Duration(seconds: 6));

          final savedOnlinePlan = plan.copyWith(
            id: stablePlanId,
            title: planTitle,
            ownerId: uid,
            isSystem: false,
          );

          await _cacheLocalPlan(
            savedOnlinePlan,
            uid: uid,
            removePendingSyncId: plan.id,
          );
          return savedOnlinePlan;
        } catch (e) {
          if (e is PostgrestException && (e.code == '28000' || e.code == '42501')) {
            rethrow;
          }
          // Fall through to offline cache handling
        }
      }

      // 2. Offline fallback: Persist with stable ID and enqueue
      final localPlanId = (plan.id.isEmpty || plan.id.startsWith('draft_'))
          ? 'local_${DateTime.now().millisecondsSinceEpoch}'
          : plan.id;

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
    } finally {
      _inFlightPlanSaves.remove(plan.id);
    }
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

      final mappedId = _isUuid(plan.id) ? plan.id : _deterministicUuid(plan.id);
      final existingIndex = cachedPlans.indexWhere(
        (p) =>
            p.id == plan.id ||
            p.id == mappedId ||
            (removePendingSyncId != null &&
                (p.id == removePendingSyncId ||
                    p.id == _deterministicUuid(removePendingSyncId))),
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
        pendingIds.remove(_deterministicUuid(removePendingSyncId));
      }

      if (markPendingSync) {
        if (!pendingIds.contains(plan.id)) {
          pendingIds.add(plan.id);
        }
      } else {
        pendingIds.remove(plan.id);
        pendingIds.remove(mappedId);
      }
      await prefs.setStringList(syncQueueKey, pendingIds);
    } catch (_) {}
  }

  Future<void> _syncPendingPlans(String uid) async {
    final client = _client;
    if (client == null) return;
    if (_isSyncing) return;

    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < const Duration(seconds: 3)) {
      return;
    }

    _isSyncing = true;
    _lastSyncTime = DateTime.now();

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

      if (_catalogToDbUuid.isEmpty) {
        await _loadAssetExercises();
      }

      for (final planId in List<String>.from(pendingIds)) {
        final plan = cachedList.firstWhere(
          (p) => p.id == planId,
          orElse: () => const WorkoutPlan(id: '', title: '', days: []),
        );
        if (plan.id.isEmpty) {
          pendingIds.remove(planId);
          continue;
        }

        final attemptKey = 'sync_attempts_$planId';
        final attempts = prefs.getInt(attemptKey) ?? 0;

        try {
          final stablePlanId =
              _isUuid(plan.id) ? plan.id : _deterministicUuid(plan.id);
          final planTitle =
              plan.title.trim().isEmpty ? 'My Custom Plan' : plan.title.trim();

          final planPayload = <String, dynamic>{
            'id': stablePlanId,
            'title': planTitle,
            'goal': plan.goal,
            'level': plan.level,
            'is_system': false,
            'owner_id': uid,
            'days': [
              for (final day in plan.days)
                {
                  if (_isUuid(day.id)) 'id': day.id,
                  'day_number': day.dayNumber,
                  'name': day.name,
                  'exercises': [
                    for (final ex in day.exercises)
                      {
                        if (_isUuid(ex.id)) 'id': ex.id,
                        'exercise_id': resolveExerciseUuid(ex.exerciseId),
                        'sort_order': ex.sortOrder,
                        'sets': ex.sets,
                        'reps': ex.reps,
                        'duration_sec': ex.durationSec,
                        'rest_sec': ex.restSec,
                      },
                  ],
                },
            ],
          };

          await client
              .rpc('save_workout_plan', params: {'p_plan': planPayload})
              .timeout(const Duration(seconds: 6));

          pendingIds.remove(planId);
          await prefs.remove(attemptKey);

          final idx = cachedList.indexWhere((p) => p.id == planId);
          if (idx >= 0) {
            cachedList[idx] = plan.copyWith(id: stablePlanId);
          }
        } catch (e) {
          final nextAttempts = attempts + 1;
          await prefs.setInt(attemptKey, nextAttempts);

          final code = e is PostgrestException ? e.code : null;
          final errStr = e.toString();
          final isPermanent = nextAttempts >= 3 ||
              (code != null &&
                  (code == '42501' ||
                      code.startsWith('22') ||
                      code.startsWith('23') ||
                      code.startsWith('42'))) ||
              errStr.contains('22P02') ||
              errStr.contains('42501') ||
              errStr.contains('235');

          if (isPermanent) {
            pendingIds.remove(planId);
            await prefs.remove(attemptKey);
          }
          break;
        }
      }

      await prefs.setStringList(syncQueueKey, pendingIds);
      await prefs.setString(
          cacheKey, jsonEncode([for (final p in cachedList) p.toJson()]));
    } catch (_) {
      // Ignore background sync errors
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Future<void> deletePlan(String id) async {
    final uid = await _resolveUserId();
    final client = _client;
    final targetId = _isUuid(id) ? id : _deterministicUuid(id);

    if (client != null && uid != null && uid.isNotEmpty) {
      try {
        await client
            .from('workout_plans')
            .delete()
            .eq('id', targetId)
            .timeout(_remoteTimeout);
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey =
          uid != null ? 'cached_my_plans_$uid' : 'cached_my_plans_default';
      final syncQueueKey = uid != null
          ? 'pending_sync_workout_plans_$uid'
          : 'pending_sync_workout_plans_default';

      final pendingIds = prefs.getStringList(syncQueueKey) ?? [];
      pendingIds.remove(id);
      pendingIds.remove(targetId);
      await prefs.setStringList(syncQueueKey, pendingIds);

      final raw = prefs.getString(cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((m) => WorkoutPlan.fromJson(Map<String, dynamic>.from(m as Map)))
            .where((p) => p.id != id && p.id != targetId)
            .toList();
        await prefs
            .setString(cacheKey, jsonEncode([for (final p in list) p.toJson()]));
      }
    } catch (_) {}
  }
}
