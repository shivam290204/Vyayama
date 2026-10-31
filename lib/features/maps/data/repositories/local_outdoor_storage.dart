import 'dart:convert';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_tombstone_journal.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_tombstone.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local offline persistence for recorded GPS outdoor activities, saved routes,
/// and crash-durable persistent tombstone journaling.
class LocalOutdoorStorage {
  const LocalOutdoorStorage({
    SharedPreferences? preferences,
    OutdoorTombstoneJournal? tombstoneJournal,
  })  : _injectedPrefs = preferences,
        _journal = tombstoneJournal ?? const OutdoorTombstoneJournal();

  final SharedPreferences? _injectedPrefs;
  final OutdoorTombstoneJournal _journal;

  static const String _activitiesKey = 'vyayama_outdoor_activities_v1';
  static const String _savedRoutesKey = 'vyayama_saved_routes_v1';
  static const String _tombstonesKey = 'vyayama_outdoor_tombstones_v2';

  Future<SharedPreferences> _getPrefs() async {
    return _injectedPrefs ?? await SharedPreferences.getInstance();
  }

  // --- Outdoor Activities ---

  /// Retrieves stored outdoor activities.
  /// If [userId] is specified, filters out activities belonging to other accounts,
  /// preserving strict user account isolation on shared devices.
  /// Automatically filters out any tombstoned records to guarantee that if a crash
  /// occurred between tombstone persistence and local file removal, the record remains hidden.
  Future<List<OutdoorActivity>> getAllActivities({String? userId}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getStringList(_activitiesKey);
    final tombstones = await getTombstones(entityType: 'activity');
    final tombstonedIds = tombstones.map((t) => t.id).toSet();

    if (raw == null || raw.isEmpty) return [];

    final list = <OutdoorActivity>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final activity = OutdoorActivity.fromJson(decoded);

        // Hide tombstoned activities immediately
        if (tombstonedIds.contains(activity.id)) {
          continue;
        }

        // Filter by user account if requested
        if (userId != null) {
          if (activity.userId == userId || activity.userId == 'local_user') {
            list.add(activity);
          }
        } else {
          list.add(activity);
        }
      } catch (_) {
        // Skip corrupted entries gracefully
      }
    }
    // Sort descending by start time
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  /// Persists an outdoor activity locally.
  /// Rejects saving if the activity is currently queued in the tombstone queue,
  /// preventing deleted activities from being resurrected by stale sync/recovery.
  Future<void> saveActivity(OutdoorActivity activity) async {
    if (await isTombstoned(activity.id, 'activity')) {
      return;
    }

    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_activitiesKey) ?? [];
    final activities = <OutdoorActivity>[];

    for (final item in rawList) {
      try {
        activities.add(OutdoorActivity.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {}
    }

    // Replace if exists, or prepend
    final index = activities.indexWhere((a) => a.id == activity.id);
    if (index >= 0) {
      activities[index] = activity;
    } else {
      activities.insert(0, activity);
    }

    final encoded = activities.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_activitiesKey, encoded);
  }

  /// Removes an activity from local storage.
  Future<void> deleteActivity(String id) async {
    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_activitiesKey) ?? [];
    final activities = <OutdoorActivity>[];

    for (final item in rawList) {
      try {
        final act = OutdoorActivity.fromJson(jsonDecode(item) as Map<String, dynamic>);
        if (act.id != id) {
          activities.add(act);
        }
      } catch (_) {}
    }

    final encoded = activities.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_activitiesKey, encoded);
  }

  // --- Saved Routes ---

  /// Retrieves stored saved routes, optionally filtered by [userId].
  /// Automatically filters out any tombstoned routes.
  Future<List<SavedRoute>> getSavedRoutes({String? userId}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getStringList(_savedRoutesKey);
    final tombstones = await getTombstones(entityType: 'route');
    final tombstonedIds = tombstones.map((t) => t.id).toSet();

    if (raw == null || raw.isEmpty) return [];

    final list = <SavedRoute>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final route = SavedRoute.fromJson(decoded);

        if (tombstonedIds.contains(route.id)) {
          continue;
        }

        if (userId != null) {
          if (route.userId == userId || route.userId == 'local_user') {
            list.add(route);
          }
        } else {
          list.add(route);
        }
      } catch (_) {
        // Skip corrupted entries
      }
    }
    return list;
  }

  /// Persists a saved route locally.
  /// Rejects saving if the route is currently in the tombstone queue.
  Future<void> saveRoute(SavedRoute route) async {
    if (await isTombstoned(route.id, 'route')) {
      return;
    }

    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_savedRoutesKey) ?? [];
    final routes = <SavedRoute>[];

    for (final item in rawList) {
      try {
        routes.add(SavedRoute.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {}
    }

    final index = routes.indexWhere((r) => r.id == route.id);
    if (index >= 0) {
      routes[index] = route;
    } else {
      routes.insert(0, route);
    }

    final encoded = routes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_savedRoutesKey, encoded);
  }

  /// Removes a saved route from local storage.
  Future<void> deleteRoute(String id) async {
    final prefs = await _getPrefs();
    final rawList = prefs.getStringList(_savedRoutesKey) ?? [];
    final routes = <SavedRoute>[];

    for (final item in rawList) {
      try {
        final r = SavedRoute.fromJson(jsonDecode(item) as Map<String, dynamic>);
        if (r.id != id) {
          routes.add(r);
        }
      } catch (_) {}
    }

    final encoded = routes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_savedRoutesKey, encoded);
  }

  Future<void> renameRoute(String id, String newName) async {
    final prefs = await _getPrefs();
    final routes = await getSavedRoutes();
    final index = routes.indexWhere((r) => r.id == id);
    if (index >= 0) {
      routes[index] = routes[index].copyWith(name: newName);
      final encoded = routes.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_savedRoutesKey, encoded);
    }
  }

  // --- Structured Tombstone Journal (Crash-Durable Ordering) ---

  /// Retrieves structured tombstones, optionally filtered by [entityType] and [userId].
  Future<List<OutdoorTombstone>> getTombstones({
    String? entityType,
    String? userId,
  }) async {
    final journalTombstones = await _journal.getAll(
      entityType: entityType,
      userId: userId,
    );
    if (journalTombstones.isNotEmpty) {
      return journalTombstones;
    }

    // Fallback/migration from SharedPreferences
    final prefs = await _getPrefs();
    final raw = prefs.getStringList(_tombstonesKey);
    if (raw == null || raw.isEmpty) return [];

    final list = <OutdoorTombstone>[];
    for (final item in raw) {
      try {
        final t = OutdoorTombstone.fromJson(jsonDecode(item) as Map<String, dynamic>);
        if (entityType != null && t.entityType != entityType) continue;
        if (userId != null && t.userId != userId && t.userId != 'local_user') continue;
        list.add(t);
        // Migrate to durable journal
        await _journal.record(t);
      } catch (_) {}
    }
    return list;
  }

  /// Persists a tombstone to durable storage using fsync flush before local record deletion.
  Future<void> recordTombstone(OutdoorTombstone tombstone) async {
    // 1. Write to atomic file journal with flush: true
    await _journal.record(tombstone);

    // 2. Also mirror to SharedPreferences for compatibility
    final prefs = await _getPrefs();
    final all = await getTombstones();
    final encoded = all.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tombstonesKey, encoded);
  }

  /// Marks a local tombstone as acknowledged and synced in Supabase outdoor_tombstones.
  Future<void> markTombstoneRemoteSynced(String id, String entityType) async {
    await _journal.markRemoteSynced(id, entityType);
    final prefs = await _getPrefs();
    final all = await getTombstones();
    final encoded = all.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tombstonesKey, encoded);
  }

  /// Removes a tombstone only after successful remote deletion and acknowledgement.
  Future<void> removeTombstone(String id, [String? entityType]) async {
    await _journal.remove(id, entityType);
    final prefs = await _getPrefs();
    final all = await getTombstones();
    final encoded = all.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_tombstonesKey, encoded);
  }

  /// Checks if a record ID is tombstoned.
  Future<bool> isTombstoned(String id, [String? entityType]) async {
    return _journal.isTombstoned(id, entityType);
  }

  // Backward-compatible helper methods
  Future<List<String>> getActivityTombstones() async {
    final tombstones = await getTombstones(entityType: 'activity');
    return tombstones.map((t) => t.id).toList();
  }

  Future<void> recordActivityTombstone(String id, {String userId = 'local_user'}) async {
    await recordTombstone(OutdoorTombstone(
      id: id,
      entityType: 'activity',
      userId: userId,
      deletedAt: DateTime.now(),
    ));
  }

  Future<void> removeActivityTombstone(String id) async {
    await removeTombstone(id, 'activity');
  }

  Future<bool> isActivityTombstoned(String id) async {
    return isTombstoned(id, 'activity');
  }

  Future<List<String>> getRouteTombstones() async {
    final tombstones = await getTombstones(entityType: 'route');
    return tombstones.map((t) => t.id).toList();
  }

  Future<void> recordRouteTombstone(String id, {String userId = 'local_user'}) async {
    await recordTombstone(OutdoorTombstone(
      id: id,
      entityType: 'route',
      userId: userId,
      deletedAt: DateTime.now(),
    ));
  }

  Future<void> removeRouteTombstone(String id) async {
    await removeTombstone(id, 'route');
  }

  Future<bool> isRouteTombstoned(String id) async {
    return isTombstoned(id, 'route');
  }

  // --- Account Migration & Cleanup ---

  /// Adopts unassigned 'local_user' activities and routes into a newly authenticated account.
  Future<void> adoptGuestData(String newUserId) async {
    final prefs = await _getPrefs();

    // 1. Adopt activities
    final allActs = await getAllActivities();
    bool actsChanged = false;
    for (int i = 0; i < allActs.length; i++) {
      if (allActs[i].userId == 'local_user') {
        allActs[i] = allActs[i].copyWith(
          userId: newUserId,
          isSynced: false, // Flag for immediate sync under new account
        );
        actsChanged = true;
      }
    }
    if (actsChanged) {
      final encoded = allActs.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList(_activitiesKey, encoded);
    }

    // 2. Adopt routes
    final allRoutes = await getSavedRoutes();
    bool routesChanged = false;
    for (int i = 0; i < allRoutes.length; i++) {
      if (allRoutes[i].userId == 'local_user') {
        allRoutes[i] = allRoutes[i].copyWith(userId: newUserId);
        routesChanged = true;
      }
    }
    if (routesChanged) {
      final encoded = allRoutes.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_savedRoutesKey, encoded);
    }

    // 3. Adopt tombstones in durable journal
    await _journal.adoptGuestData(newUserId);
  }

  /// Purges records belonging to [userId] on account sign-out or account deletion.
  Future<void> clearUserData(String userId) async {
    final prefs = await _getPrefs();

    // Purge activities
    final rawActs = prefs.getStringList(_activitiesKey) ?? [];
    final retainedActs = <String>[];
    for (final item in rawActs) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        if (decoded['user_id'] != userId) {
          retainedActs.add(item);
        }
      } catch (_) {}
    }
    await prefs.setStringList(_activitiesKey, retainedActs);

    // Purge routes
    final rawRoutes = prefs.getStringList(_savedRoutesKey) ?? [];
    final retainedRoutes = <String>[];
    for (final item in rawRoutes) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        if (decoded['user_id'] != userId) {
          retainedRoutes.add(item);
        }
      } catch (_) {}
    }
    await prefs.setStringList(_savedRoutesKey, retainedRoutes);

    // Purge user's tombstones from journal and preferences
    await _journal.clearUserData(userId);
    final allTombstones = await getTombstones();
    allTombstones.removeWhere((t) => t.userId == userId);
    await prefs.setStringList(
      _tombstonesKey,
      allTombstones.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  /// Clears all stored data (for test fixtures or complete factory reset).
  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(_activitiesKey);
    await prefs.remove(_savedRoutesKey);
    await prefs.remove(_tombstonesKey);
    await _journal.clearUserData('local_user');
  }
}
