import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository managing user saved routes with offline-first persistence.
class SavedRoutesRepository {
  const SavedRoutesRepository({
    LocalOutdoorStorage? storage,
    SupabaseClient? client,
  })  : _storage = storage ?? const LocalOutdoorStorage(),
        _client = client;

  final LocalOutdoorStorage _storage;
  final SupabaseClient? _client;

  SupabaseClient? get _supabase =>
      _client ?? (Env.isSupabaseConfigured ? Supabase.instance.client : null);

  Future<List<SavedRoute>> getSavedRoutes() async {
    return _storage.getSavedRoutes();
  }

  Future<void> saveRoute(SavedRoute route) async {
    await _storage.saveRoute(route);
    final sb = _supabase;
    final currentUser = sb?.auth.currentUser;
    if (sb != null && currentUser != null) {
      try {
        final payload = route.toJson();
        payload['user_id'] = currentUser.id;
        await sb.from('saved_routes').upsert(payload);
      } catch (e) {
        debugPrint('[SavedRoutesRepository] Remote route sync deferred: $e');
      }
    }
  }

  /// Retries syncing all local saved routes to Supabase.
  Future<int> syncPendingRoutes() async {
    final sb = _supabase;
    final currentUser = sb?.auth.currentUser;
    if (sb == null || currentUser == null) return 0;

    final routes = await _storage.getSavedRoutes();
    int syncedCount = 0;
    for (final r in routes) {
      try {
        final payload = r.toJson();
        payload['user_id'] = currentUser.id;
        await sb.from('saved_routes').upsert(payload);
        syncedCount++;
      } catch (e) {
        debugPrint('[SavedRoutesRepository] Route sync retry failed for ${r.id}: $e');
      }
    }
    return syncedCount;
  }

  Future<void> deleteRoute(String id) async {
    await _storage.deleteRoute(id);
    final sb = _supabase;
    if (sb != null && sb.auth.currentUser != null) {
      try {
        await sb.from('saved_routes').delete().eq('id', id);
      } catch (e) {
        debugPrint('[SavedRoutesRepository] Remote route delete deferred: $e');
      }
    }
  }

  Future<void> renameRoute(String id, String newName) async {
    await _storage.renameRoute(id, newName);
  }
}

