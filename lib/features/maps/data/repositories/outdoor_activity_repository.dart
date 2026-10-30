import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository managing outdoor activity lifecycle, local caching, and remote sync.
class OutdoorActivityRepository {
  const OutdoorActivityRepository({
    LocalOutdoorStorage? storage,
    SupabaseClient? client,
  })  : _storage = storage ?? const LocalOutdoorStorage(),
        _client = client;

  final LocalOutdoorStorage _storage;
  final SupabaseClient? _client;

  SupabaseClient? get _supabase =>
      _client ?? (Env.isSupabaseConfigured ? Supabase.instance.client : null);

  Future<List<OutdoorActivity>> getAllActivities() async {
    return _storage.getAllActivities();
  }

  Future<OutdoorActivity?> getActivityById(String id) async {
    final list = await _storage.getAllActivities();
    try {
      return list.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveActivity(OutdoorActivity activity) async {
    // 1. Always save locally first (offline-first guarantee)
    await _storage.saveActivity(activity);

    // 2. Attempt remote sync if connected and authenticated
    final sb = _supabase;
    final currentUser = sb?.auth.currentUser;
    if (sb != null && currentUser != null) {
      try {
        final payload = activity.toJson();
        payload['user_id'] = currentUser.id;
        await sb.from('outdoor_activities').upsert(payload);
        await _storage.saveActivity(activity.copyWith(
          isSynced: true,
          userId: currentUser.id,
        ));
      } catch (e) {
        debugPrint('[OutdoorActivityRepository] Remote sync deferred: $e');
      }
    }
  }

  /// Retries syncing all unsynced activities to Supabase.
  Future<int> syncPendingActivities() async {
    final sb = _supabase;
    final currentUser = sb?.auth.currentUser;
    if (sb == null || currentUser == null) return 0;

    final all = await _storage.getAllActivities();
    final unsynced = all.where((a) => !a.isSynced).toList();
    int syncedCount = 0;

    for (final act in unsynced) {
      try {
        final payload = act.toJson();
        payload['user_id'] = currentUser.id;
        await sb.from('outdoor_activities').upsert(payload);
        await _storage.saveActivity(act.copyWith(
          isSynced: true,
          userId: currentUser.id,
        ));
        syncedCount++;
      } catch (e) {
        debugPrint('[OutdoorActivityRepository] Sync retry failed for ${act.id}: $e');
      }
    }
    return syncedCount;
  }

  Future<void> deleteActivity(String id) async {
    await _storage.deleteActivity(id);
    final sb = _supabase;
    if (sb != null && sb.auth.currentUser != null) {
      try {
        await sb.from('outdoor_activities').delete().eq('id', id);
      } catch (e) {
        debugPrint('[OutdoorActivityRepository] Remote delete deferred: $e');
      }
    }
  }
}

