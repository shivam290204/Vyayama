import 'dart:async';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_tombstone.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository managing user saved routes with offline-first persistence,
/// semantically accurate metadata preservation, bounded backoff, and crash-safe tombstone ordering.
class SavedRoutesRepository {
  SavedRoutesRepository({
    LocalOutdoorStorage? storage,
    SupabaseClient? client,
  })  : _storage = storage ?? const LocalOutdoorStorage(),
        _client = client;

  final LocalOutdoorStorage _storage;
  final SupabaseClient? _client;

  bool _isSyncing = false;

  /// Exposes whether a route synchronization job is currently executing.
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
  Future<void> Function(String table, String id, Map<String, dynamic> updates, String userId)? remoteUpdateOverride;

  @visibleForTesting
  Future<List<Map<String, dynamic>>> Function(String table, String userId)? remoteFetchTombstonesOverride;

  @visibleForTesting
  Future<void> Function(String table, Map<String, dynamic> tombstonePayload)? remoteUpsertTombstoneOverride;

  @visibleForTesting
  String? Function()? currentUserIdOverride;

  /// Retrieves stored saved routes, scoped to the current user to preserve account isolation.
  Future<List<SavedRoute>> getSavedRoutes({String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    return _storage.getSavedRoutes(userId: effectiveUserId);
  }

  /// Saves a route locally and attempts remote synchronization if authenticated.
  Future<void> saveRoute(SavedRoute route) async {
    if (await _storage.isTombstoned(route.id, 'route')) {
      return;
    }

    // 1. Local-first persistence
    await _storage.saveRoute(route);

    // 2. Remote upsert if authenticated
    final effectiveUser = _currentUserId;
    if (effectiveUser != null) {
      try {
        final payload = toSupabasePayload(route, effectiveUser);
        if (remoteUpsertOverride != null) {
          await _retryWithBackoff(() => remoteUpsertOverride!('saved_routes', payload));
        } else if (_supabase != null) {
          await _retryWithBackoff(() => _supabase!.from('saved_routes').upsert(payload));
        }
      } catch (e) {
        debugPrint('[SavedRoutesRepository] Remote route sync deferred: network unreachable or busy.');
      }
    }
  }

  /// Retries syncing all local saved routes to Supabase, pulling remote tombstones, and processing pending deletions.
  Future<int> syncPendingRoutes() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    try {
      final effectiveUser = _currentUserId;
      if (effectiveUser == null) return 0;

      // --- Step 0: Pull Remote Tombstones (Cross-Device Deletion Synchronization) ---
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
              .eq('entity_type', 'route');
          remoteTombstones = List<Map<String, dynamic>>.from(res as List);
        }

        for (final row in remoteTombstones) {
          final remoteTombstone = OutdoorTombstone.fromJson(row).copyWith(
            isRemoteSynced: true,
          );
          await _storage.recordTombstone(remoteTombstone);
          // Purge stale local route immediately
          await _storage.deleteRoute(remoteTombstone.id);
        }
      } catch (e) {
        debugPrint('[SavedRoutesRepository] Remote route tombstone pull deferred: $e');
      }

      // --- Step 1: Process Route Deletion Tombstones FIRST ---
      final tombstones = await _storage.getTombstones(
        entityType: 'route',
        userId: effectiveUser,
      );
      final pendingTombstones =
          tombstones.where((t) => !t.isRemoteSynced).toList();

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
                  .upsert(t.toRemotePayload()),
            );
          }

          if (remoteDeleteOverride != null) {
            await _retryWithBackoff(
              () => remoteDeleteOverride!('saved_routes', t.id, effectiveUser),
            );
          } else if (_supabase != null) {
            await _retryWithBackoff(
              () => _supabase!
                  .from('saved_routes')
                  .delete()
                  .eq('id', t.id)
                  .eq('user_id', effectiveUser),
            );
          }
          await _storage.markTombstoneRemoteSynced(t.id, 'route');
        } catch (e) {
          debugPrint('[SavedRoutesRepository] Route tombstone retry deferred for ID.');
        }
      }

      // --- Step 2: Sync Pending Routes ---
      final routes = await _storage.getSavedRoutes(userId: effectiveUser);
      int syncedCount = 0;

      for (final r in routes) {
        if (await _storage.isTombstoned(r.id, 'route')) {
          continue;
        }

        // Account isolation: never sync routes belonging to a different user
        if (r.userId != effectiveUser && r.userId != 'local_user') {
          continue;
        }

        try {
          final payload = toSupabasePayload(r, effectiveUser);
          if (remoteUpsertOverride != null) {
            await _retryWithBackoff(() => remoteUpsertOverride!('saved_routes', payload));
          } else if (_supabase != null) {
            await _retryWithBackoff(() => _supabase!.from('saved_routes').upsert(payload));
          }
          syncedCount++;
        } catch (e) {
          debugPrint('[SavedRoutesRepository] Route sync retry failed for route.');
        }
      }

      return syncedCount;
    } finally {
      _isSyncing = false;
    }
  }

  /// Deletes a saved route using a strict, crash-safe 4-step sequence:
  /// 1. Persist a tombstone containing entity type, record ID and owner user ID FIRST.
  /// 2. Hide/remove the record from local storage.
  /// 3. Upload tombstone to Supabase `outdoor_tombstones` and delete from `saved_routes`.
  /// 4. Mark local tombstone as remote synced (retained locally to prevent resurrection).
  Future<void> deleteRoute(String id) async {
    final effectiveUser = _currentUserId ?? 'local_user';

    final tombstone = OutdoorTombstone(
      id: id,
      entityType: 'route',
      userId: effectiveUser,
      deletedAt: DateTime.now(),
      isRemoteSynced: false,
    );

    // 1. Persist tombstone containing entity type, record ID and owner user ID FIRST
    await _storage.recordTombstone(tombstone);

    // 2. Hide/remove the record from visible local results
    await _storage.deleteRoute(id);

    // 3. Attempt remote delete if authenticated
    if (_currentUserId != null) {
      try {
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
                .upsert(tombstone.toRemotePayload()),
          );
        }

        if (remoteDeleteOverride != null) {
          await _retryWithBackoff(
            () => remoteDeleteOverride!('saved_routes', id, effectiveUser),
          );
        } else if (_supabase != null) {
          await _retryWithBackoff(
            () => _supabase!
                .from('saved_routes')
                .delete()
                .eq('id', id)
                .eq('user_id', effectiveUser),
          );
        }
        // 4. Mark local tombstone as remote synced
        await _storage.markTombstoneRemoteSynced(id, 'route');
      } catch (e) {
        debugPrint('[SavedRoutesRepository] Remote route delete deferred: queued tombstone.');
      }
    }
  }

  Future<void> renameRoute(String id, String newName) async {
    await _storage.renameRoute(id, newName);
    final effectiveUser = _currentUserId;
    if (effectiveUser != null) {
      try {
        if (remoteUpdateOverride != null) {
          await _retryWithBackoff(() => remoteUpdateOverride!('saved_routes', id, {'name': newName}, effectiveUser));
        } else if (_supabase != null) {
          await _retryWithBackoff(
            () => _supabase!
                .from('saved_routes')
                .update({'name': newName})
                .eq('id', id)
                .eq('user_id', effectiveUser),
          );
        }
      } catch (e) {
        debugPrint('[SavedRoutesRepository] Remote rename deferred.');
      }
    }
  }

  /// Converts a [SavedRoute] into a remote payload.
  /// Strictly preserves actual route characteristics without silently inventing values:
  /// - Preserves 'surface_type' as 'unknown' if not known (requires migration 020 in production)
  /// - Preserves 'elevation_profile' as 'unknown' if not known (requires migration 020 in production)
  /// - Enforces non-null numeric(6,2) for 'elevation_gain_meters'
  /// - Strips client-only fields ('is_loop', 'is_difficulty_estimated')
  static Map<String, dynamic> toSupabasePayload(SavedRoute route, String userId) {
    return {
      'id': route.id,
      'user_id': userId,
      'name': route.name,
      'activity_type': route.activityType.name,
      'distance_meters': route.distanceMeters,
      'estimated_duration_sec': route.estimatedDurationSeconds,
      'difficulty': route.difficulty.name,
      'points': route.points.map((p) => p.toJson()).toList(),
      'elevation_gain_meters': route.elevationGainMeters ?? 0.0,
      'surface_type': route.surfaceType.name, // Preserves actual 'unknown' without inventing 'paved'
      'elevation_profile': route.elevationProfile.name, // Preserves actual 'unknown' without inventing 'flat'
      'description': route.description,
      'is_saved_by_user': route.isSavedByUser,
      'created_at': (route.createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

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
