import 'dart:async';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository managing user saved routes with offline-first persistence,
/// Supabase schema-compatible payload sanitization, bounded backoff, and offline tombstones.
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
  String? Function()? currentUserIdOverride;

  /// Retrieves stored saved routes, scoped to the current user to preserve account isolation.
  Future<List<SavedRoute>> getSavedRoutes({String? userId}) async {
    final effectiveUserId = userId ?? _currentUserId;
    return _storage.getSavedRoutes(userId: effectiveUserId);
  }

  /// Saves a route locally and attempts remote synchronization if authenticated.
  Future<void> saveRoute(SavedRoute route) async {
    if (await _storage.isRouteTombstoned(route.id)) {
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

  /// Retries syncing all local saved routes to Supabase and processes pending deletions.
  Future<int> syncPendingRoutes() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    try {
      final effectiveUser = _currentUserId;
      if (effectiveUser == null) return 0;

      // --- Step 1: Process Route Deletion Tombstones ---
      final tombstones = await _storage.getRouteTombstones();
      for (final id in tombstones) {
        try {
          if (remoteDeleteOverride != null) {
            await _retryWithBackoff(() => remoteDeleteOverride!('saved_routes', id, effectiveUser));
          } else if (_supabase != null) {
            await _retryWithBackoff(
              () => _supabase!
                  .from('saved_routes')
                  .delete()
                  .eq('id', id)
                  .eq('user_id', effectiveUser),
            );
          }
          await _storage.removeRouteTombstone(id);
        } catch (e) {
          debugPrint('[SavedRoutesRepository] Route tombstone retry deferred for ID.');
        }
      }

      // --- Step 2: Sync Pending Routes ---
      final routes = await _storage.getSavedRoutes(userId: effectiveUser);
      int syncedCount = 0;

      for (final r in routes) {
        if (await _storage.isRouteTombstoned(r.id)) {
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

  /// Deletes a saved route immediately from local storage and queues a tombstone.
  Future<void> deleteRoute(String id) async {
    // 1. Delete locally immediately
    await _storage.deleteRoute(id);

    // 2. Record tombstone
    await _storage.recordRouteTombstone(id);

    // 3. Attempt remote delete if authenticated
    final effectiveUser = _currentUserId;
    if (effectiveUser != null) {
      try {
        if (remoteDeleteOverride != null) {
          await _retryWithBackoff(() => remoteDeleteOverride!('saved_routes', id, effectiveUser));
        } else if (_supabase != null) {
          await _retryWithBackoff(
            () => _supabase!
                .from('saved_routes')
                .delete()
                .eq('id', id)
                .eq('user_id', effectiveUser),
          );
        }
        await _storage.removeRouteTombstone(id);
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

  /// Sanitizes a [SavedRoute] into a Map that strictly complies with the Supabase
  /// migration 019 schema constraints:
  /// - Strips client-only fields ('is_loop', 'is_difficulty_estimated')
  /// - Enforces non-null numeric(6,2) for 'elevation_gain_meters'
  /// - Normalizes 'surface_type' to ('paved', 'trail', 'mixed')
  /// - Normalizes 'elevation_profile' to ('flat', 'moderate', 'hilly')
  static Map<String, dynamic> toSupabasePayload(SavedRoute route, String userId) {
    // Check constraints in migration 019:
    // surface_type in ('paved', 'trail', 'mixed')
    final String surface;
    switch (route.surfaceType) {
      case RouteSurface.paved:
        surface = 'paved';
        break;
      case RouteSurface.trail:
        surface = 'trail';
        break;
      case RouteSurface.mixed:
        surface = 'mixed';
        break;
      case RouteSurface.unknown:
        surface = 'paved'; // Safe fallback adhering to schema check constraint
        break;
    }

    // elevation_profile in ('flat', 'moderate', 'hilly')
    final String elevation;
    switch (route.elevationProfile) {
      case RouteElevation.flat:
        elevation = 'flat';
        break;
      case RouteElevation.moderate:
        elevation = 'moderate';
        break;
      case RouteElevation.hilly:
        elevation = 'hilly';
        break;
      case RouteElevation.unknown:
        elevation = 'flat'; // Safe fallback adhering to schema check constraint
        break;
    }

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
      'surface_type': surface,
      'elevation_profile': elevation,
      'description': route.description,
      'is_saved_by_user': route.isSavedByUser,
      'created_at': (route.createdAt ?? DateTime.now()).toIso8601String(),
      // 'is_loop' and 'is_difficulty_estimated' are omitted to avoid PostgreSQL column mismatch
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
