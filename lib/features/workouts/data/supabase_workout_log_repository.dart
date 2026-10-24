import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/features/workouts/data/workout_log.dart';
import 'package:fitbuddy/features/workouts/data/workout_log_repository.dart';

/// Supabase implementation of [WorkoutLogRepository] backed by `workout_logs`.
/// Fully offline-capable: persists logs to local storage outbox when offline
/// and syncs pending logs upon reconnect.
class SupabaseWorkoutLogRepository implements WorkoutLogRepository {
  SupabaseWorkoutLogRepository({
    SupabaseClient? client,
    SharedPreferences? prefs,
  })  : _client = client ?? _safeClient(),
        _prefs = prefs;

  static SupabaseClient? _safeClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  final SupabaseClient? _client;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _asyncPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> _resolveUserId() async {
    try {
      final user = _client?.auth.currentUser;
      if (user != null) return user.id;
    } catch (_) {}
    try {
      final p = await _asyncPrefs;
      return p.getString('last_signed_in_user_id');
    } catch (_) {}
    return null;
  }

  @override
  Future<WorkoutLog> logWorkout({
    required String planDayId,
    required int durationMin,
    required int caloriesBurned,
    DateTime? completedAt,
  }) async {
    final time = (completedAt ?? DateTime.now()).toUtc();
    final uid = await _resolveUserId() ?? 'local_user';
    final client = _client;

    if (client != null && uid != 'local_user') {
      try {
        final res = await client.from('workout_logs').insert({
          'user_id': uid,
          'plan_day_id': planDayId.isEmpty ? null : planDayId,
          'completed_at': time.toIso8601String(),
          'duration_min': durationMin,
          'calories_burned': caloriesBurned,
        }).select().single();

        final remoteLog = WorkoutLog.fromJson(Map<String, dynamic>.from(res));
        await _saveLogToLocalCache(remoteLog, uid: uid);
        return remoteLog;
      } catch (_) {
        // Fall back to offline persistence
      }
    }

    final offlineLog = WorkoutLog(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: uid,
      planDayId: planDayId,
      completedAt: time,
      durationMin: durationMin,
      caloriesBurned: caloriesBurned,
    );

    await _saveLogToLocalCache(offlineLog, uid: uid, markPendingSync: true);
    return offlineLog;
  }

  @override
  Future<List<WorkoutLog>> getLogs({DateTime? since}) async {
    final uid = await _resolveUserId() ?? 'local_user';
    final client = _client;

    if (client != null && uid != 'local_user') {
      await syncPendingLogs();

      try {
        var query = client.from('workout_logs').select().eq('user_id', uid);
        if (since != null) {
          query = query.gte('completed_at', since.toUtc().toIso8601String());
        }
        final res = await query.order('completed_at', ascending: false);
        final remoteLogs = (res as List)
            .map((row) => WorkoutLog.fromJson(Map<String, dynamic>.from(row)))
            .toList();

        // Also merge any unsynced offline logs
        final pendingLogs = await _getPendingLogs(uid);
        for (final pl in pendingLogs) {
          if (!remoteLogs.any((r) => r.id == pl.id)) {
            if (since == null || pl.completedAt.isAfter(since) || pl.completedAt.isAtSameMomentAs(since)) {
              remoteLogs.add(pl);
            }
          }
        }
        remoteLogs.sort((a, b) => b.completedAt.compareTo(a.completedAt));

        // Update local cache
        await _updateLocalCache(remoteLogs, uid: uid);
        return remoteLogs;
      } catch (_) {
        // Fall back to local cache
      }
    }

    // Offline fallback: load from SharedPreferences cache
    final cached = await _loadLocalCachedLogs(uid);
    if (since != null) {
      return cached
          .where((l) => l.completedAt.isAfter(since) || l.completedAt.isAtSameMomentAs(since))
          .toList();
    }
    return cached;
  }

  @override
  Future<bool> hasWorkoutOn(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day).toUtc();
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).toUtc();
    final uid = await _resolveUserId() ?? 'local_user';
    final client = _client;

    if (client != null && uid != 'local_user') {
      try {
        final res = await client
            .from('workout_logs')
            .select('id')
            .eq('user_id', uid)
            .gte('completed_at', start.toIso8601String())
            .lte('completed_at', end.toIso8601String())
            .limit(1);

        if ((res as List).isNotEmpty) return true;
      } catch (_) {}
    }

    // Check local cache
    final localLogs = await _loadLocalCachedLogs(uid);
    return localLogs.any((log) =>
        (log.completedAt.isAfter(start) || log.completedAt.isAtSameMomentAs(start)) &&
        (log.completedAt.isBefore(end) || log.completedAt.isAtSameMomentAs(end)));
  }

  /// Drains and uploads all pending offline workout logs to Supabase.
  Future<void> syncPendingLogs([String? overrideUid]) async {
    final uid = overrideUid ?? await _resolveUserId();
    final client = _client;
    if (client == null || uid == null || uid == 'local_user') return;

    try {
      final p = await _asyncPrefs;
      final pendingKey = 'pending_sync_workout_logs_$uid';
      final pendingRawList = p.getStringList(pendingKey) ?? [];
      if (pendingRawList.isEmpty) return;

      final remaining = <String>[];
      for (final raw in pendingRawList) {
        try {
          final log = WorkoutLog.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
          await client.from('workout_logs').insert({
            'user_id': uid,
            'plan_day_id': log.planDayId.isEmpty ? null : log.planDayId,
            'completed_at': log.completedAt.toUtc().toIso8601String(),
            'duration_min': log.durationMin,
            'calories_burned': log.caloriesBurned,
          });
        } catch (_) {
          remaining.add(raw);
        }
      }
      await p.setStringList(pendingKey, remaining);
    } catch (_) {}
  }

  Future<void> _saveLogToLocalCache(
    WorkoutLog log, {
    required String uid,
    bool markPendingSync = false,
  }) async {
    try {
      final p = await _asyncPrefs;
      final cached = await _loadLocalCachedLogs(uid);
      cached.removeWhere((l) => l.id == log.id);
      cached.insert(0, log);
      await _updateLocalCache(cached, uid: uid);

      if (markPendingSync) {
        final pendingKey = 'pending_sync_workout_logs_$uid';
        final pendingList = p.getStringList(pendingKey) ?? [];
        pendingList.add(jsonEncode(log.toJson()));
        await p.setStringList(pendingKey, pendingList);
      }
    } catch (_) {}
  }

  Future<List<WorkoutLog>> _loadLocalCachedLogs(String uid) async {
    try {
      final p = await _asyncPrefs;
      final cacheKey = 'cached_workout_logs_$uid';
      var raw = p.getString(cacheKey);
      if (raw == null || raw.isEmpty) {
        for (final k in p.getKeys()) {
          if (k.startsWith('cached_workout_logs_')) {
            raw = p.getString(k);
            if (raw != null && raw.isNotEmpty) break;
          }
        }
      }
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        final logs = list
            .map((item) => WorkoutLog.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        logs.sort((a, b) => b.completedAt.compareTo(a.completedAt));
        return logs;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _updateLocalCache(List<WorkoutLog> logs, {required String uid}) async {
    try {
      final p = await _asyncPrefs;
      final cacheKey = 'cached_workout_logs_$uid';
      await p.setString(
        cacheKey,
        jsonEncode([for (final log in logs) log.toJson()]),
      );
    } catch (_) {}
  }

  Future<List<WorkoutLog>> _getPendingLogs(String uid) async {
    try {
      final p = await _asyncPrefs;
      final pendingKey = 'pending_sync_workout_logs_$uid';
      final list = p.getStringList(pendingKey) ?? [];
      return [
        for (final item in list)
          WorkoutLog.fromJson(Map<String, dynamic>.from(jsonDecode(item) as Map)),
      ];
    } catch (_) {
      return [];
    }
  }
}
