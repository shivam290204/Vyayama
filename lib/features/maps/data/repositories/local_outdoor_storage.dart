import 'dart:convert';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local offline persistence for recorded GPS outdoor activities and saved routes.
class LocalOutdoorStorage {
  const LocalOutdoorStorage();

  static const String _activitiesKey = 'vyayama_outdoor_activities_v1';
  static const String _savedRoutesKey = 'vyayama_saved_routes_v1';

  // --- Outdoor Activities ---

  Future<List<OutdoorActivity>> getAllActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_activitiesKey);
    if (raw == null || raw.isEmpty) return [];

    final list = <OutdoorActivity>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        list.add(OutdoorActivity.fromJson(decoded));
      } catch (_) {
        // Skip corrupted entries gracefully
      }
    }
    // Sort descending by start time
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  Future<void> saveActivity(OutdoorActivity activity) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = await getAllActivities();

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

  Future<void> deleteActivity(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final activities = await getAllActivities();
    activities.removeWhere((a) => a.id == id);
    final encoded = activities.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_activitiesKey, encoded);
  }

  // --- Saved Routes ---

  Future<List<SavedRoute>> getSavedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_savedRoutesKey);
    if (raw == null || raw.isEmpty) return [];

    final list = <SavedRoute>[];
    for (final item in raw) {
      try {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        list.add(SavedRoute.fromJson(decoded));
      } catch (_) {
        // Skip corrupted entries
      }
    }
    return list;
  }

  Future<void> saveRoute(SavedRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();

    final index = routes.indexWhere((r) => r.id == route.id);
    if (index >= 0) {
      routes[index] = route;
    } else {
      routes.insert(0, route);
    }

    final encoded = routes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_savedRoutesKey, encoded);
  }

  Future<void> deleteRoute(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();
    routes.removeWhere((r) => r.id == id);
    final encoded = routes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_savedRoutesKey, encoded);
  }

  Future<void> renameRoute(String id, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();
    final index = routes.indexWhere((r) => r.id == id);
    if (index >= 0) {
      routes[index] = routes[index].copyWith(name: newName);
      final encoded = routes.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_savedRoutesKey, encoded);
    }
  }
}

