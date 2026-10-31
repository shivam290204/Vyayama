import 'dart:async';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository managing outdoor activity lifecycle, local-first offline caching,
/// resilient Supabase synchronization with bounded backoff, and offline tombstones.
class OutdoorActivityRepository {
  OutdoorActivityRepository({
    LocalOutdoorStorage? storage,
    SupabaseClient? client,
  })  : _storage = storage ?? const LocalOutdoorStorage(),
        _client = client;

  final LocalOutdoorStorage _storage;
  final SupabaseClient? _client;

  bool _isSyncing = false;

  /// Exposes whether a background or manual sync is currently in progress.
  bool get isSyncing => _isSyncing;

  SupabaseClient? get _supabase =>
      _client ?? (Env.isSupabaseConfigured ? Supabase.instance.client : null);

  String? get _currentUserId =>
      currentUserIdOverride != null ? currentUserIdOverride!() : _supabase?.auth.currentUser?.id;

  @visibleForTesting
  Future<void> Function(String table, Map<String, dynamic> payload)? remoteUpsertOverride;

  @visibleForTesting
  Future<void> Function(String table, String id, String userId)? remoteDeleteOverride;

  @visibleForTesting
  String? Function()? currentUserIdOverride;

  /// Retrieves all recorded activities, scoped to the authenticated user to ensure
  /// strict account isolation. If no user is logged in, returns local guest activities.
  Future<List<OutdoorActivity>> getAllActivities({String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    return _storage.getAllActivities(userId: effectiveUserId);
  }

  /// Retrieves a specific activity by ID.
  Future<OutdoorActivity?> getActivityById(String id) async {
    final list = await _storage.getAllActivities();
    try {
      return list.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Persists a completed or updated outdoor activity.
  /// Guarantees offline-first persistence before attempting remote Supabase upsert.
  Future<void> saveActivity(OutdoorActivity activity) async {
    // 0. Do not save or resurrect activities that have been deleted locally
    if (await _storage.isActivityTombstoned(activity.id)) {
      return;
    }

    // 1. Always save locally first (offline-first guarantee)
    await _storage.saveActivity(activity);

    // 2. Attempt remote sync if connected and authenticated
    final effectiveUser = _currentUserId;
    if (effectiveUser != null) {
      try {
        final payload = activity.toJson();
        payload['user_id'] = effectiveUser;

        if (remoteUpsertOverride != null) {
          await _retryWithBackoff(() => remoteUpsertOverride!('outdoor_activities', payload));
        } else if (_supabase != null) {
          await _retryWithBackoff(() => _supabase!.from('outdoor_activities').upsert(payload));
        }

        await _storage.saveActivity(activity.copyWith(
          isSynced: true,
          userId: effectiveUser,
        ));
      } catch (e) {
        // Log clean diagnostic without exposing raw coordinates or auth tokens
        debugPrint('[OutdoorActivityRepository] Remote sync deferred: network unreachable or server busy.');
      }
    }
  }

  /// Deletes an activity with immediate local removal and persistent tombstone queueing.
  /// If the device is offline or the remote request fails, the tombstone persists across
  /// restarts and will be retried when connectivity is restored.
  Future<void> deleteActivity(String id) async {
    // 1. Delete locally immediately
    await _storage.deleteActivity(id);

    // 2. Record tombstone in persistent queue
    await _storage.recordActivityTombstone(id);

    // 3. Attempt remote deletion if authenticated
    final effectiveUser = _currentUserId;
    if (effectiveUser != null) {
      try {
        if (remoteDeleteOverride != null) {
          await _retryWithBackoff(() => remoteDeleteOverride!('outdoor_activities', id, effectiveUser));
        } else if (_supabase != null) {
          await _retryWithBackoff(
            () => _supabase!
                .from('outdoor_activities')
                .delete()
                .eq('id', id)
                .eq('user_id', effectiveUser),
          );
        }
        // Remote delete succeeded: remove from tombstone queue
        await _storage.removeActivityTombstone(id);
      } catch (e) {
        debugPrint('[OutdoorActivityRepository] Remote delete deferred: queued tombstone.');
      }
    }
  }

  /// Synchronizes pending activities and processes offline deletion tombstones.
  /// Uses an in-flight lock to prevent concurrent sync executions.
  Future<int> syncPendingActivities() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    try {
      final effectiveUser = _currentUserId;
      if (effectiveUser == null) return 0;

      // --- Step 1: Process Deletion Tombstones ---
      final tombstones = await _storage.getActivityTombstones();
      for (final id in tombstones) {
        try {
          if (remoteDeleteOverride != null) {
            await _retryWithBackoff(() => remoteDeleteOverride!('outdoor_activities', id, effectiveUser));
          } else if (_supabase != null) {
            await _retryWithBackoff(
              () => _supabase!
                  .from('outdoor_activities')
                  .delete()
                  .eq('id', id)
                  .eq('user_id', effectiveUser),
            );
          }
          await _storage.removeActivityTombstone(id);
        } catch (e) {
          debugPrint('[OutdoorActivityRepository] Tombstone retry deferred for ID.');
        }
      }

      // --- Step 2: Sync Pending Activities ---
      final all = await _storage.getAllActivities(userId: effectiveUser);
      final unsynced = all.where((a) => !a.isSynced).toList();
      int syncedCount = 0;

      for (final act in unsynced) {
        // Prevent resurrection if item is tombstoned
        if (await _storage.isActivityTombstoned(act.id)) {
          continue;
        }

        // Account isolation: never sync records belonging to a different user
        if (act.userId != effectiveUser && act.userId != 'local_user') {
          continue;
        }

        try {
          final payload = act.toJson();
          payload['user_id'] = effectiveUser;

          if (remoteUpsertOverride != null) {
            await _retryWithBackoff(() => remoteUpsertOverride!('outdoor_activities', payload));
          } else if (_supabase != null) {
            await _retryWithBackoff(() => _supabase!.from('outdoor_activities').upsert(payload));
          }

          await _storage.saveActivity(act.copyWith(
            isSynced: true,
            userId: effectiveUser,
          ));
          syncedCount++;
        } catch (e) {
          debugPrint('[OutdoorActivityRepository] Sync retry failed for activity.');
        }
      }

      return syncedCount;
    } finally {
      _isSyncing = false;
    }
  }

  /// Helper executing [operation] with bounded exponential backoff up to [maxAttempts].
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 300),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      attempts++;
      try {
        return await operation();
      } catch (e) {
        if (attempts >= maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 2).clamp(300, 2000));
      }
    }
  }
}
