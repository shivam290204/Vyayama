import 'dart:convert';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local offline persistence for recorded GPS outdoor activities and saved routes,
/// with user isolation and persistent tombstone queue for reliable offline deletion.
class LocalOutdoorStorage {
  const LocalOutdoorStorage({SharedPreferences? preferences})
      : _injectedPrefs = preferences;

  final SharedPreferences? _injectedPrefs;

  static const String _activitiesKey = 'vyayama_outdoor_activities_v1';
  static const String _savedRoutesKey = 'vyayama_saved_routes_v1';
  static const String _activityTombstonesKey =
      'vyayama_outdoor_activity_tombstones_v1';
  static const String _routeTombstonesKey = 'vyayama_saved_route_tombstones_v1';

  Future<SharedPreferences> _getPrefs() async {
    return _injectedPrefs ?? await SharedPreferences.getInstance();
  }

  // --- Outdoor Activities ---

  /// Retrieves stored outdoor activities.
  /// If [userId] is specified, filters out activities belonging to other accounts,
  /// preserving strict user account isolation on shared devices.
  Future<List<OutdoorActivity>> getAllActivities({String? userId}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getStringList(_activitiesKey);
    if (raw == null || raw.isEmpty) return [];

    final list = <OutdoorActivity>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final activity = OutdoorActivity.fromJson(decoded);

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
    if (await isActivityTombstoned(activity.id)) {
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

  /// Removes an activity from local storage immediately.
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

  // --- Activity Tombstone Queue (Offline Deletion) ---

  /// Returns the list of activity IDs pending remote deletion.
  Future<List<String>> getActivityTombstones() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(_activityTombstonesKey) ?? [];
  }

  /// Records an activity ID in the persistent tombstone queue.
  Future<void> recordActivityTombstone(String id) async {
    final prefs = await _getPrefs();
    final tombstones = (prefs.getStringList(_activityTombstonesKey) ?? []).toSet();
    tombstones.add(id);
    await prefs.setStringList(_activityTombstonesKey, tombstones.toList());
  }

  /// Removes an activity ID from the persistent tombstone queue after remote success.
  Future<void> removeActivityTombstone(String id) async {
    final prefs = await _getPrefs();
    final tombstones = (prefs.getStringList(_activityTombstonesKey) ?? []).toSet();
    tombstones.remove(id);
    await prefs.setStringList(_activityTombstonesKey, tombstones.toList());
  }

  /// Checks if an activity ID is in the tombstone queue.
  Future<bool> isActivityTombstoned(String id) async {
    final prefs = await _getPrefs();
    final tombstones = prefs.getStringList(_activityTombstonesKey) ?? [];
    return tombstones.contains(id);
  }

  // --- Saved Routes ---

  /// Retrieves stored saved routes, optionally filtered by [userId].
  Future<List<SavedRoute>> getSavedRoutes({String? userId}) async {
    final prefs = await _getPrefs();
    final raw = prefs.getStringList(_savedRoutesKey);
    if (raw == null || raw.isEmpty) return [];

    final list = <SavedRoute>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        final route = SavedRoute.fromJson(decoded);

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
    if (await isRouteTombstoned(route.id)) {
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

  /// Removes a saved route from local storage immediately.
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

  // --- Route Tombstone Queue (Offline Deletion) ---

  /// Returns the list of route IDs pending remote deletion.
  Future<List<String>> getRouteTombstones() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(_routeTombstonesKey) ?? [];
  }

  /// Records a route ID in the persistent tombstone queue.
  Future<void> recordRouteTombstone(String id) async {
    final prefs = await _getPrefs();
    final tombstones = (prefs.getStringList(_routeTombstonesKey) ?? []).toSet();
    tombstones.add(id);
    await prefs.setStringList(_routeTombstonesKey, tombstones.toList());
  }

  /// Removes a route ID from the persistent tombstone queue after remote success.
  Future<void> removeRouteTombstone(String id) async {
    final prefs = await _getPrefs();
    final tombstones = (prefs.getStringList(_routeTombstonesKey) ?? []).toSet();
    tombstones.remove(id);
    await prefs.setStringList(_routeTombstonesKey, tombstones.toList());
  }

  /// Checks if a route ID is in the tombstone queue.
  Future<bool> isRouteTombstoned(String id) async {
    final prefs = await _getPrefs();
    final tombstones = prefs.getStringList(_routeTombstonesKey) ?? [];
    return tombstones.contains(id);
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
  }

  /// Purges records belonging to [userId] on account sign-out or account deletion.
  Future<void> clearUserData(String userId) async {
    final prefs = await _getPrefs();

    // Purge activities
    final allActs = await getAllActivities();
    final retainedActs = allActs.where((a) => a.userId != userId).toList();
    await prefs.setStringList(
      _activitiesKey,
      retainedActs.map((a) => jsonEncode(a.toJson())).toList(),
    );

    // Purge routes
    final allRoutes = await getSavedRoutes();
    final retainedRoutes = allRoutes.where((r) => r.userId != userId).toList();
    await prefs.setStringList(
      _savedRoutesKey,
      retainedRoutes.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// Clears all stored data (for test fixtures or complete factory reset).
  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(_activitiesKey);
    await prefs.remove(_savedRoutesKey);
    await prefs.remove(_activityTombstonesKey);
    await prefs.remove(_routeTombstonesKey);
  }
}
