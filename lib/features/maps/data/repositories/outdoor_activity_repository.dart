import 'dart:async';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_tombstone.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository managing outdoor activity lifecycle, local-first offline caching,
/// resilient Supabase synchronization with bounded backoff, and crash-safe tombstone ordering.
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
  Future<List<Map<String, dynamic>>> Function(String table, String userId)? remoteFetchTombstonesOverride;

  @visibleForTesting
  Future<void> Function(String table, Map<String, dynamic> tombstonePayload)? remoteUpsertTombstoneOverride;

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
    if (await _storage.isTombstoned(activity.id, 'activity')) {
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
        if (isTombstoneRejection(e)) {
          await _storage.deleteActivity(activity.id);
          await _storage.recordTombstone(OutdoorTombstone(
            id: activity.id,
            entityType: 'activity',
            userId: effectiveUser,
            deletedAt: DateTime.now(),
            isRemoteSynced: true,
          ));
          debugPrint('[OutdoorActivityRepository] Stale activity rejected by server tombstone; purged local copy.');
        } else {
          // Log clean diagnostic without exposing raw coordinates or auth tokens
          debugPrint('[OutdoorActivityRepository] Remote sync deferred: network unreachable or server busy.');
        }
      }
    }
  }

  /// Checks if an error represents an active tombstone rejection from PostgreSQL.
  static bool isTombstoneRejection(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('tombstone_exists') ||
        msg.contains('active tombstone') ||
        msg.contains('deleted by an active tombstone');
  }

  /// Deletes an activity using a strict, crash-safe 4-step sequence:
  /// 1. Persist a tombstone containing entity type, record ID and owner user ID FIRST.
  /// 2. Hide/remove the record from local storage.
  /// 3. Upload tombstone to Supabase `outdoor_tombstones` and delete from `outdoor_activities`.
  /// 4. Mark local tombstone as remote synced (retained locally to prevent resurrection).
  Future<void> deleteActivity(String id) async {
    final effectiveUser = _currentUserId ?? 'local_user';

    final tombstone = OutdoorTombstone(
      id: id,
      entityType: 'activity',
      userId: effectiveUser,
      deletedAt: DateTime.now(),
      isRemoteSynced: false,
    );

    // 1. Persist tombstone containing entity type, record ID and owner user ID FIRST
    await _storage.recordTombstone(tombstone);

    // 2. Hide/remove the record from visible local results
    await _storage.deleteActivity(id);

    // 3. Attempt remote tombstone upload and remote record deletion if authenticated
    if (_currentUserId != null) {
      try {
        // Upload tombstone to Supabase outdoor_tombstones table
        if (remoteUpsertTombstoneOverride != null) {
          await _retryWithBackoff(
            () => remoteUpsertTombstoneOverride!(
              'outdoor_tombstones',
              tombstone.toRemotePayload(),
            ),
          );
        } else if (_supabase != null) {
          await _retryWithBackoff(
            () => _supabase!
                .from('outdoor_tombstones')
                .upsert(
                  tombstone.toRemotePayload(),
                  onConflict: 'id,entity_type,user_id',
                  ignoreDuplicates: true,
                ),
          );
        }

        // Delete remote record from outdoor_activities table
        if (remoteDeleteOverride != null) {
          await _retryWithBackoff(
            () => remoteDeleteOverride!('outdoor_activities', id, effectiveUser),
          );
        } else if (_supabase != null) {
          await _retryWithBackoff(
            () => _supabase!
                .from('outdoor_activities')
                .delete()
                .eq('id', id)
                .eq('user_id', effectiveUser),
          );
        }

        // 4. Mark local tombstone as acknowledged and synced
        await _storage.markTombstoneRemoteSynced(id, 'activity');
      } catch (e) {
        debugPrint('[OutdoorActivityRepository] Remote delete deferred: queued tombstone.');
      }
    }
  }

  /// Synchronizes pending activities, downloads remote tombstones, and processes offline deletion tombstones.
  /// Uses an in-flight lock to prevent concurrent sync executions.
  Future<int> syncPendingActivities() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    try {
      final effectiveUser = _currentUserId;
      if (effectiveUser == null) return 0;

      // --- Step 0: Download Remote Tombstones (Cross-Device Deletion Sync) ---
      // Ensures that if Device A deleted a record on another device, this device downloads
      // the tombstone and purges its local copy BEFORE uploading any pending activities!
      try {
        List<Map<String, dynamic>> remoteTombstones = [];
        if (remoteFetchTombstonesOverride != null) {
          remoteTombstones = await remoteFetchTombstonesOverride!(
            'outdoor_tombstones',
            effectiveUser,
          );
        } else if (_supabase != null) {
          final res = await _supabase!
              .from('outdoor_tombstones')
              .select()
              .eq('user_id', effectiveUser)
              .eq('entity_type', 'activity');
          remoteTombstones = List<Map<String, dynamic>>.from(res as List);
        }

        for (final row in remoteTombstones) {
          final remoteTombstone = OutdoorTombstone.fromJson(row).copyWith(
            isRemoteSynced: true,
          );
          await _storage.recordTombstone(remoteTombstone);
          // Purge stale local copy immediately
          await _storage.deleteActivity(remoteTombstone.id);
        }
      } catch (e) {
        debugPrint('[OutdoorActivityRepository] Remote tombstone pull deferred: $e');
      }

      // --- Step 1: Process Local Unsynced Tombstones ---
      final localTombstones = await _storage.getTombstones(
        entityType: 'activity',
        userId: effectiveUser,
      );
      final pendingTombstones =
          localTombstones.where((t) => !t.isRemoteSynced).toList();

      for (final t in pendingTombstones) {
        try {
          if (remoteUpsertTombstoneOverride != null) {
            await _retryWithBackoff(
              () => remoteUpsertTombstoneOverride!(
                'outdoor_tombstones',
                t.toRemotePayload(),
              ),
            );
          } else if (_supabase != null) {
            await _retryWithBackoff(
              () => _supabase!
                  .from('outdoor_tombstones')
                  .upsert(
                    t.toRemotePayload(),
                    onConflict: 'id,entity_type,user_id',
                    ignoreDuplicates: true,
                  ),
            );
          }

          if (remoteDeleteOverride != null) {
            await _retryWithBackoff(
              () => remoteDeleteOverride!('outdoor_activities', t.id, effectiveUser),
            );
          } else if (_supabase != null) {
            await _retryWithBackoff(
              () => _supabase!
                  .from('outdoor_activities')
                  .delete()
                  .eq('id', t.id)
                  .eq('user_id', effectiveUser),
            );
          }
          await _storage.markTombstoneRemoteSynced(t.id, 'activity');
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
        if (await _storage.isTombstoned(act.id, 'activity')) {
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
          if (isTombstoneRejection(e)) {
            // Stale activity rejected by tombstone on server: purge local copy immediately and record tombstone
            await _storage.deleteActivity(act.id);
            await _storage.recordTombstone(OutdoorTombstone(
              id: act.id,
              entityType: 'activity',
              userId: effectiveUser,
              deletedAt: DateTime.now(),
              isRemoteSynced: true,
            ));
            debugPrint('[OutdoorActivityRepository] Stale activity rejected by server tombstone; purged local copy.');
          } else {
            debugPrint('[OutdoorActivityRepository] Sync retry failed for activity.');
          }
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
        if (isTombstoneRejection(e) || attempts >= maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 2).clamp(300, 2000));
      }
    }
  }
}
