import 'dart:async';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_tombstone.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository managing user saved routes with offline-first persistence,
/// semantically accurate metadata preservation, bounded backoff, and crash-safe tombstone ordering.
///
/// CONCURRENCY & TRANSACTION ISOLATION REQUIREMENT:
/// Saved route synchronization strictly relies on PostgreSQL READ COMMITTED isolation
/// (the default transaction isolation level in Supabase / PostgREST).
/// - Each synchronization database operation uses a separate, single-statement Supabase PostgREST request,
///   guaranteeing a fresh transaction and fresh MVCC snapshot per attempt.
/// - Changing the authenticated role's 'default_transaction_isolation' to 'REPEATABLE READ' is
///   UNSUPPORTED with the current advisory-lock-only design; advisory locks do not refresh frozen snapshots.
/// - Repeatable Read safety is not claimed without row-level sentinel locks.
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

  /// Checks if an error represents an active tombstone rejection from PostgreSQL.
  /// Inspects typed [PostgrestException] fields (code, details, message) before falling back to string inspection.
  static bool isTombstoneRejection(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      final details = error.details?.toString().toLowerCase() ?? '';
      final message = error.message.toLowerCase();

      // Check PostgreSQL custom error code P0001 with TOMBSTONE_EXISTS detail or tombstone message
      if (code == 'P0001' && (details.contains('tombstone_exists') || message.contains('tombstone'))) {
        return true;
      }
      if (details.contains('tombstone_exists') ||
          message.contains('active tombstone') ||
          message.contains('deleted by an active tombstone')) {
        return true;
      }
    }

    final msg = error.toString().toLowerCase();
    return msg.contains('tombstone_exists') ||
        msg.contains('active tombstone') ||
        msg.contains('deleted by an active tombstone');
  }

  /// Categorizes sync errors into retryable transient failures vs permanent non-retryable rejections.
  ///
  /// Explicitly Retryable (bounded backoff with fresh transaction / request):
  /// - PostgreSQL 40001 (serialization_failure)
  /// - PostgreSQL 40P01 (deadlock_detected)
  /// - Appropriate transient server failures:
  ///   - HTTP status 429 (rate limit), 500, 502, 503, 504
  ///   - PostgreSQL 53300 (too_many_connections), 57P01 (admin_shutdown)
  /// - Network / socket failures (SocketException, ClientException, TimeoutException)
  ///
  /// Explicitly Non-Retryable (permanent failures / fail-fast):
  /// - PostgreSQL P0001 / TOMBSTONE_EXISTS (active tombstone rejection - handled by caller)
  /// - PostgreSQL 42501 (insufficient_privilege)
  /// - Class 23 constraint violations (23505 unique, 23503 foreign key, 23502 not null, 23514 check)
  /// - Class 22 data exceptions, Class 42 syntax or access rule violations
  static bool isRetryableSyncError(Object error) {
    if (isTombstoneRejection(error)) {
      return false;
    }

    if (error is PostgrestException) {
      final code = (error.code ?? '').toUpperCase();
      final message = error.message.toLowerCase();
      final details = error.details?.toString().toLowerCase() ?? '';

      // 1. Explicitly retryable PostgreSQL codes and transient HTTP status codes
      if (code == '40001' || // serialization_failure
          code == '40P01' || // deadlock_detected
          code == '53300' || // too_many_connections
          code == '57P01' || // admin_shutdown
          code == '429' || // Too Many Requests
          code == '500' || // Internal Server Error
          code == '502' || // Bad Gateway
          code == '503' || // Service Unavailable
          code == '504') { // Gateway Timeout
        return true;
      }

      // 2. Explicitly non-retryable PostgreSQL codes (SQLSTATE length is 5 characters)
      if (code == '42501' || // insufficient_privilege
          (code.length == 5 &&
              (code.startsWith('23') || // integrity constraint violations (23505, 23503, 23502, 23514)
                  code.startsWith('22') || // data exceptions
                  code.startsWith('42')))) { // syntax error or access rule violation
        return false;
      }

      // 4. Message or details containing serialization or deadlock indicators
      if (message.contains('serialization') ||
          message.contains('deadlock') ||
          details.contains('serialization') ||
          details.contains('deadlock')) {
        return true;
      }

      return false;
    }

    final errStr = error.toString().toLowerCase();

    // Explicit string checks for serialization and deadlock
    if (errStr.contains('40001') ||
        errStr.contains('serialization_failure') ||
        errStr.contains('could not serialize access') ||
        errStr.contains('40p01') ||
        errStr.contains('deadlock detected') ||
        errStr.contains('deadlock_detected')) {
      return true;
    }

    // Explicit non-retryable string checks (privileges, constraints)
    if (errStr.contains('42501') ||
        errStr.contains('insufficient_privilege') ||
        errStr.contains('permission denied') ||
        errStr.contains('violates foreign key') ||
        errStr.contains('violates check constraint') ||
        errStr.contains('violates not-null') ||
        errStr.contains('violates unique constraint')) {
      return false;
    }

    // Network & transport errors (retryable)
    if (errStr.contains('socketexception') ||
        errStr.contains('clientexception') ||
        errStr.contains('timeoutexception') ||
        errStr.contains('timed out') ||
        errStr.contains('network is unreachable') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection closed') ||
        errStr.contains('connection reset') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('handshake failed') ||
        errStr.contains('502') ||
        errStr.contains('503') ||
        errStr.contains('504') ||
        errStr.contains('429')) {
      return true;
    }

    return false;
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
        if (isTombstoneRejection(e)) {
          await _storage.deleteRoute(route.id);
          await _storage.recordTombstone(OutdoorTombstone(
            id: route.id,
            entityType: 'route',
            userId: effectiveUser,
            deletedAt: DateTime.now(),
            isRemoteSynced: true,
          ));
          debugPrint('[SavedRoutesRepository] Stale route rejected by server tombstone; purged local copy.');
        } else {
          debugPrint('[SavedRoutesRepository] Remote route sync deferred: network unreachable or busy.');
        }
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
                  .upsert(
                    t.toRemotePayload(),
                    onConflict: 'id,entity_type,user_id',
                    ignoreDuplicates: true,
                  ),
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
          if (isTombstoneRejection(e)) {
            // Stale route rejected by server tombstone: purge local copy immediately and record local tombstone
            await _storage.deleteRoute(r.id);
            await _storage.recordTombstone(OutdoorTombstone(
              id: r.id,
              entityType: 'route',
              userId: effectiveUser,
              deletedAt: DateTime.now(),
              isRemoteSynced: true,
            ));
            debugPrint('[SavedRoutesRepository] Stale route rejected by server tombstone; purged local copy.');
          } else {
            debugPrint('[SavedRoutesRepository] Route sync retry failed for route.');
          }
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
                .upsert(
                  tombstone.toRemotePayload(),
                  onConflict: 'id,entity_type,user_id',
                  ignoreDuplicates: true,
                ),
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
  /// Converts a [SavedRoute] into a remote Supabase row payload.
  /// Strictly preserves actual route characteristics without silently inventing false values:
  /// - Preserves 'surface_type' as 'unknown' if not known (requires migration 020 in production)
  /// - Preserves 'elevation_profile' as 'unknown' if not known (requires migration 020 in production)
  /// - Preserves nullable 'elevation_gain_meters' (null if not available)
  /// - Synchronizes 'is_loop' and 'is_difficulty_estimated'
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
      'elevation_gain_meters': route.elevationGainMeters,
      'surface_type': route.surfaceType.name,
      'elevation_profile': route.elevationProfile.name,
      'description': route.description,
      'is_saved_by_user': route.isSavedByUser,
      'created_at': (route.createdAt ?? DateTime.now()).toIso8601String(),
      'is_loop': route.isLoop,
      'is_difficulty_estimated': route.isDifficultyEstimated,
    };
  }

  /// Helper executing [operation] with bounded exponential backoff up to [maxAttempts].
  /// Retries the complete REST request using a fresh transaction for transient failures
  /// (SQLSTATE 40001, 40P01, network, 5xx), while immediately rethrowing permanent errors
  /// (tombstone rejection P0001, insufficient privilege 42501, constraint violations 23xxx).
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
        if (!isRetryableSyncError(e) || attempts >= maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(delay);
        delay = Duration(milliseconds: (delay.inMilliseconds * 2).clamp(300, 2000));
      }
    }
  }
}
