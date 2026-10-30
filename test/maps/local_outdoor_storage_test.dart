import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalOutdoorStorage Offline Persistence Tests', () {
    late LocalOutdoorStorage storage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      storage = const LocalOutdoorStorage();
    });

    final testTime = DateTime(2026, 10, 29, 14, 0, 0);

    test('1. Saves, retrieves, and deletes recorded outdoor activity', () async {
      final activity = OutdoorActivity(
        id: 'act_101',
        userId: 'u_123',
        activityType: OutdoorActivityType.running,
        startTime: testTime,
        endTime: testTime.add(const Duration(minutes: 30)),
        durationSeconds: 1800,
        distanceMeters: 5200,
        averagePaceSecondsPerKm: 346,
        averageSpeedKmh: 10.4,
        points: [
          GpsPoint(latitude: 40.7128, longitude: -74.0060, timestamp: testTime),
          GpsPoint(latitude: 40.7200, longitude: -74.0060, timestamp: testTime.add(const Duration(minutes: 15))),
        ],
        elevationGainMeters: 45.0,
        caloriesBurned: 410,
        title: 'Central Park 5K',
      );

      // Save
      await storage.saveActivity(activity);

      // Retrieve
      final list = await storage.getAllActivities();
      expect(list.length, equals(1));
      expect(list.first.id, equals('act_101'));
      expect(list.first.title, equals('Central Park 5K'));
      expect(list.first.distanceMeters, equals(5200));
      expect(list.first.points.length, equals(2));

      // Delete
      await storage.deleteActivity('act_101');
      final listAfter = await storage.getAllActivities();
      expect(listAfter, isEmpty);
    });

    test('2. Saves, renames, and deletes saved routes', () async {
      final route = SavedRoute(
        id: 'route_202',
        name: 'Riverwalk Trail',
        activityType: OutdoorActivityType.walking,
        distanceMeters: 3100,
        estimatedDurationSeconds: 2400,
        difficulty: RouteDifficulty.easy,
        points: [
          GpsPoint(latitude: 40.7128, longitude: -74.0060, timestamp: testTime),
        ],
        surfaceType: RouteSurface.paved,
      );

      // Save
      await storage.saveRoute(route);
      final routes = await storage.getSavedRoutes();
      expect(routes.length, equals(1));
      expect(routes.first.name, equals('Riverwalk Trail'));

      // Rename
      await storage.renameRoute('route_202', 'Hudson River Sunset Trail');
      final renamedRoutes = await storage.getSavedRoutes();
      expect(renamedRoutes.first.name, equals('Hudson River Sunset Trail'));

      // Delete
      await storage.deleteRoute('route_202');
      final emptyRoutes = await storage.getSavedRoutes();
      expect(emptyRoutes, isEmpty);
    });
  });
}

