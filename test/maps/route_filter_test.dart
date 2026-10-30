import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteFilter Matching and CopyWith Tests', () {
    final routeEasyWalk = SavedRoute(
      id: 'r1',
      name: 'Lakeview Walking Loop',
      activityType: OutdoorActivityType.walking,
      distanceMeters: 2500, // 2.5 km
      estimatedDurationSeconds: 1800,
      difficulty: RouteDifficulty.easy,
      surfaceType: RouteSurface.paved,
      elevationProfile: RouteElevation.flat,
      description: 'Paved family walk along the lake',
      points: [GpsPoint(latitude: 0, longitude: 0, timestamp: DateTime.now())],
    );

    final routeHardHike = SavedRoute(
      id: 'r2',
      name: 'Ridgecrest Mountain Hike',
      activityType: OutdoorActivityType.hiking,
      distanceMeters: 8500, // 8.5 km
      estimatedDurationSeconds: 7200,
      difficulty: RouteDifficulty.hard,
      surfaceType: RouteSurface.trail,
      elevationProfile: RouteElevation.hilly,
      description: 'Rugged terrain with steep climbs',
      points: [GpsPoint(latitude: 0, longitude: 0, timestamp: DateTime.now())],
    );

    test('1. Filters routes by activity type', () {
      const walkFilter = RouteFilter(activityType: OutdoorActivityType.walking);
      const hikeFilter = RouteFilter(activityType: OutdoorActivityType.hiking);

      expect(walkFilter.matches(routeEasyWalk), isTrue);
      expect(walkFilter.matches(routeHardHike), isFalse);

      expect(hikeFilter.matches(routeHardHike), isTrue);
      expect(hikeFilter.matches(routeEasyWalk), isFalse);
    });

    test('2. Filters routes by distance boundaries', () {
      const shortFilter = RouteFilter(maxDistanceKm: 3.0);
      const longFilter = RouteFilter(minDistanceKm: 5.0);

      expect(shortFilter.matches(routeEasyWalk), isTrue); // 2.5 km <= 3.0 km
      expect(shortFilter.matches(routeHardHike), isFalse); // 8.5 km > 3.0 km

      expect(longFilter.matches(routeHardHike), isTrue); // 8.5 km >= 5.0 km
      expect(longFilter.matches(routeEasyWalk), isFalse); // 2.5 km < 5.0 km
    });

    test('3. Filters routes by difficulty and surface type', () {
      const easyPavedFilter = RouteFilter(
        difficulty: RouteDifficulty.easy,
        surface: RouteSurface.paved,
      );

      expect(easyPavedFilter.matches(routeEasyWalk), isTrue);
      expect(easyPavedFilter.matches(routeHardHike), isFalse);
    });

    test('4. Matches search query against name and description', () {
      const searchLake = RouteFilter(searchQuery: 'lake');
      const searchMountain = RouteFilter(searchQuery: 'mountain');
      const searchUnmatched = RouteFilter(searchQuery: 'desert');

      expect(searchLake.matches(routeEasyWalk), isTrue);
      expect(searchLake.matches(routeHardHike), isFalse);

      expect(searchMountain.matches(routeHardHike), isTrue);
      expect(searchUnmatched.matches(routeEasyWalk), isFalse);
    });
  });
}

