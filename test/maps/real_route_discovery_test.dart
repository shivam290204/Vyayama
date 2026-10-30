import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/real_route_discovery_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/services/route_discovery_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// ─── Stub Overpass ──────────────────────────────────────────────────────────

class _FakeOverpass extends OverpassService {
  _FakeOverpass(this._places, {this.exceptionToThrow})
      : super(cache: RouteCache.instance);
  final List<OverpassPlace> _places;
  final Exception? exceptionToThrow;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return _places;
  }
}

// ─── Stub Valhalla ──────────────────────────────────────────────────────────

class _FakeValhalla extends ValhallaService {
  _FakeValhalla(this._route, {this.exceptionToThrow});
  final ValhallaRoute? _route;
  final Exception? exceptionToThrow;

  @override
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return _route;
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _RealServiceStub extends RealRouteDiscoveryService {
  _RealServiceStub({
    required OverpassService overpass,
    required ValhallaService valhalla,
  }) : super(overpass: overpass, valhalla: valhalla);
}

_RealServiceStub _makeService({
  required List<OverpassPlace> places,
  required ValhallaRoute? valhallaRoute,
  Exception? overpassError,
  Exception? valhallaError,
}) =>
    _RealServiceStub(
      overpass: _FakeOverpass(places, exceptionToThrow: overpassError),
      valhalla: _FakeValhalla(valhallaRoute, exceptionToThrow: valhallaError),
    );

// ─── Sample fixture data ─────────────────────────────────────────────────────

const _center = LatLng(51.505, -0.09); // London

OverpassPlace _park(int id, String name, double lat, double lon,
        {bool isNamed = true}) =>
    OverpassPlace(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      tags: const {'leisure': 'park'},
      isNamed: isNamed,
    );

final _validRoute = ValhallaRoute(
  points: [
    const LatLng(51.505, -0.09),
    const LatLng(51.506, -0.091),
    const LatLng(51.507, -0.092),
    const LatLng(51.508, -0.091),
    const LatLng(51.505, -0.09),
  ],
  distanceMeters: 2800,
  durationSeconds: 1980,
  isLoopOverride: true,
);

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() => RouteCache.instance.clear());

  // 1. OverpassPlace classification & derivation ─────────────────────────────

  group('OverpassPlace classification & derivation', () {
    test('1. isPark true for leisure=park and nature_reserve', () {
      const place1 = OverpassPlace(
        id: 1,
        name: 'Riverside Park',
        lat: 51.505,
        lon: -0.09,
        tags: {'leisure': 'park'},
      );
      const place2 = OverpassPlace(
        id: 2,
        name: 'Woodland Reserve',
        lat: 51.505,
        lon: -0.09,
        tags: {'leisure': 'nature_reserve'},
      );
      expect(place1.isPark, isTrue);
      expect(place2.isPark, isTrue);
      expect(place1.isTrail, isFalse);
    });

    test('2. isTrail true for highway=footway, path, and track', () {
      const footway = OverpassPlace(
        id: 2,
        name: 'River Walk',
        lat: 51.505,
        lon: -0.09,
        tags: {'highway': 'footway'},
      );
      const path = OverpassPlace(
        id: 3,
        name: 'Hill Path',
        lat: 51.505,
        lon: -0.09,
        tags: {'highway': 'path'},
      );
      expect(footway.isTrail, isTrue);
      expect(path.isTrail, isTrue);
      expect(footway.isPark, isFalse);
    });

    test('3. isHikingRoute true for route=hiking and sac_scale', () {
      const hikePlace = OverpassPlace(
        id: 4,
        name: 'Highland Trail',
        lat: 51.505,
        lon: -0.09,
        tags: {'route': 'hiking'},
      );
      const ruggedPlace = OverpassPlace(
        id: 5,
        name: 'Ridge Path',
        lat: 51.505,
        lon: -0.09,
        tags: {'highway': 'path', 'sac_scale': 'mountain_hiking'},
      );
      expect(hikePlace.isHikingRoute, isTrue);
      expect(ruggedPlace.isHikingRoute, isTrue);
    });

    test('4. Derives honest descriptive names for unnamed features without fictional nouns', () {
      expect(
        OverpassPlace.deriveDescriptiveName({'highway': 'footway'}),
        equals('Mapped Footway'),
      );
      expect(
        OverpassPlace.deriveDescriptiveName({'highway': 'path'}),
        equals('Pedestrian Path'),
      );
      expect(
        OverpassPlace.deriveDescriptiveName({'leisure': 'park'}),
        equals('Park Pathway'),
      );
      expect(
        OverpassPlace.deriveDescriptiveName({'route': 'hiking'}),
        equals('Mapped Hiking Trail'),
      );
      expect(
        OverpassPlace.deriveDescriptiveName({'name': 'Victoria Embankment'}),
        equals('Victoria Embankment'),
      );
    });

    test('5. Parses Overpass JSON with ways and centers correctly', () {
      final service = OverpassService();
      const mockJson = '''
{
  "elements": [
    {
      "type": "way",
      "id": 101,
      "center": { "lat": 51.508, "lon": -0.092 },
      "tags": { "highway": "footway", "name": "Thames Path" }
    },
    {
      "type": "way",
      "id": 102,
      "center": { "lat": 51.509, "lon": -0.093 },
      "tags": { "highway": "path" }
    }
  ]
}
''';
      final places = service.parseOverpassResponse(mockJson);
      expect(places, hasLength(2));
      expect(places[0].id, equals(101));
      expect(places[0].name, equals('Thames Path'));
      expect(places[0].isNamed, isTrue);

      expect(places[1].id, equals(102));
      expect(places[1].name, equals('Pedestrian Path'));
      expect(places[1].isNamed, isFalse);
    });
  });

  // 2. Error and exception handling ──────────────────────────────────────────

  group('Route discovery error propagation', () {
    test('6. OverpassService throws RouteRateLimitException on 429', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [],
          valhallaRoute: null,
          overpassError: const RouteRateLimitException(),
        ),
      );

      expect(
        () => engine.discoverRoutes(center: _center),
        throwsA(isA<RouteRateLimitException>()),
      );
    });

    test('7. OverpassService throws RouteNetworkException on connectivity failure', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [],
          valhallaRoute: null,
          overpassError: const RouteNetworkException(),
        ),
      );

      expect(
        () => engine.discoverRoutes(center: _center),
        throwsA(isA<RouteNetworkException>()),
      );
    });

    test('8. OverpassService throws OverpassServiceException on server error', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [],
          valhallaRoute: null,
          overpassError: const OverpassServiceException(),
        ),
      );

      expect(
        () => engine.discoverRoutes(center: _center),
        throwsA(isA<OverpassServiceException>()),
      );
    });

    test('9. ValhallaService throws ValhallaRoutingException on routing engine failure', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [_park(1, 'Hyde Park', 51.506, -0.091)],
          valhallaRoute: null,
          valhallaError: const ValhallaRoutingException(),
        ),
      );

      expect(
        () => engine.discoverRoutes(center: _center),
        throwsA(isA<ValhallaRoutingException>()),
      );
    });
  });

  // 3. Valhalla polyline decoder & loop detection ─────────────────────────────

  group('Valhalla polyline decoder & geometry analysis', () {
    test('10. Parses valid trip JSON with correct distance and duration', () {
      final service = ValhallaService();
      const json = '''
{
  "trip": {
    "summary": { "length": 2.8, "time": 1980 },
    "legs": [
      {
        "shape": "mfp|Idf|@mA?mA?mA@"
      }
    ]
  }
}
''';
      final parsed = service.testParseRoute(json);
      expect(parsed, isNotNull);
      expect(parsed!.distanceMeters, closeTo(2800, 1));
      expect(parsed.durationSeconds, closeTo(1980, 1));
    });

    test('11. Detects retraced out-and-back route correctly', () {
      // Outward leg: (0,0) -> (0,0.01) -> (0,0.02)
      // Return leg: (0,0.02) -> (0,0.01) -> (0,0) [retraced along exact same coordinates]
      final retracedPoints = [
        const LatLng(51.500, -0.090),
        const LatLng(51.502, -0.090),
        const LatLng(51.504, -0.090),
        const LatLng(51.506, -0.090),
        const LatLng(51.508, -0.090),
        const LatLng(51.508, -0.090),
        const LatLng(51.506, -0.090),
        const LatLng(51.504, -0.090),
        const LatLng(51.502, -0.090),
        const LatLng(51.500, -0.090),
      ];
      final route = ValhallaRoute(
        points: retracedPoints,
        distanceMeters: 1800,
        durationSeconds: 1200,
      );
      expect(route.isLoop, isFalse, reason: 'Retraced out-and-back must not be labeled as loop');
    });

    test('12. Detects polygon circuit loop correctly', () {
      // Distinct polygon circuit (divergent outbound and return)
      final loopPoints = [
        const LatLng(51.500, -0.090),
        const LatLng(51.505, -0.080),
        const LatLng(51.510, -0.085),
        const LatLng(51.512, -0.095),
        const LatLng(51.508, -0.105),
        const LatLng(51.503, -0.100),
        const LatLng(51.500, -0.090),
        const LatLng(51.500, -0.090),
        const LatLng(51.500, -0.090),
        const LatLng(51.500, -0.090),
      ];
      final route = ValhallaRoute(
        points: loopPoints,
        distanceMeters: 3200,
        durationSeconds: 2200,
      );
      expect(route.isLoop, isTrue, reason: 'Divergent circular path must be labeled as loop');
    });
  });

  // 4. Activity type suitability & filtering ─────────────────────────────────

  group('Activity type suitability and RouteFilter', () {
    const walkRoute = SavedRoute(
      id: 'w1',
      name: 'Paved Park Walk',
      activityType: OutdoorActivityType.walking,
      distanceMeters: 2500,
      estimatedDurationSeconds: 1800,
      difficulty: RouteDifficulty.easy,
      surfaceType: RouteSurface.paved,
      points: [],
    );

    const trailHike = SavedRoute(
      id: 'h1',
      name: 'Mountain Ridge Trail',
      activityType: OutdoorActivityType.hiking,
      distanceMeters: 7500,
      estimatedDurationSeconds: 6500,
      difficulty: RouteDifficulty.hard,
      surfaceType: RouteSurface.trail,
      points: [],
    );

    test('13. Paved walking route is suitable for both walking and running', () {
      expect(walkRoute.isSuitableFor(OutdoorActivityType.walking), isTrue);
      expect(walkRoute.isSuitableFor(OutdoorActivityType.running), isTrue);
      expect(walkRoute.isSuitableFor(OutdoorActivityType.hiking), isFalse);
    });

    test('14. Rugged trail hike is not suitable for running', () {
      expect(trailHike.isSuitableFor(OutdoorActivityType.hiking), isTrue);
      expect(trailHike.isSuitableFor(OutdoorActivityType.running), isFalse);
    });

    test('15. RouteFilter with running includes paved pedestrian routes', () {
      const runFilter = RouteFilter(activityType: OutdoorActivityType.running);
      expect(runFilter.matches(walkRoute), isTrue);
      expect(runFilter.matches(trailHike), isFalse);
    });

    test('16. RouteFilter with hiking includes only genuine trail routes', () {
      const hikeFilter = RouteFilter(activityType: OutdoorActivityType.hiking);
      expect(hikeFilter.matches(trailHike), isTrue);
      expect(hikeFilter.matches(walkRoute), isFalse);
    });
  });

  // 5. Missing metadata handling ─────────────────────────────────────────────

  group('Missing geographic metadata handling', () {
    test('17. Formats unavailable elevation as -- without claiming +0m flat', () {
      const route = SavedRoute(
        id: 'r_no_elev',
        name: 'City Footway',
        activityType: OutdoorActivityType.walking,
        distanceMeters: 1500,
        estimatedDurationSeconds: 1000,
        difficulty: RouteDifficulty.easy,
        surfaceType: RouteSurface.unknown,
        elevationProfile: RouteElevation.unknown,
        points: [],
      );

      expect(route.elevationGainMeters, isNull);
      expect(route.hasElevationData, isFalse);
      expect(route.formattedElevation, equals('--'));
      expect(route.surfaceType, equals(RouteSurface.unknown));
      expect(route.elevationProfile, equals(RouteElevation.unknown));
    });
  });

  // 6. Real discovery flow with stubs ────────────────────────────────────────

  group('RealRouteDiscoveryService with stubs', () {
    test('18. Returns empty list when Overpass returns no places', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(places: [], valhallaRoute: null),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isEmpty);
    });

    test('19. Generates named loop when companion waypoint is found', () async {
      final p1 = OverpassPlace(
        id: 1,
        name: 'Hyde Park',
        lat: 51.507,
        lon: -0.095,
        tags: const {'leisure': 'park'},
      );
      final p2 = OverpassPlace(
        id: 2,
        name: 'Kensington Gardens',
        lat: 51.503,
        lon: -0.085,
        tags: const {'leisure': 'park'},
      );

      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [p1, p2],
          valhallaRoute: _validRoute,
        ),
      );

      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isNotEmpty);
      expect(routes.first.isLoop, isTrue);
      expect(routes.first.name, contains('Loop'));
    });

    test('20. Deduplicates routes with nearly identical distance', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [
            _park(1, 'Park Alpha', 51.506, -0.091),
            _park(2, 'Park Beta', 51.506, -0.092),
          ],
          valhallaRoute: _validRoute,
        ),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes.length, lessThanOrEqualTo(1));
    });

    test('21. Filters routes shorter than 300 meters', () async {
      const shortRoute = ValhallaRoute(
        points: [LatLng(51.505, -0.09), LatLng(51.506, -0.09)],
        distanceMeters: 120,
        durationSeconds: 90,
      );
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [_park(1, 'Courtyard', 51.506, -0.091)],
          valhallaRoute: shortRoute,
        ),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isEmpty);
    });
  });

  // 7. RouteDiscoveryEngine test fixtures ────────────────────────────────────

  group('RouteDiscoveryEngine test fixtures', () {
    test('22. generateTestRoutes returns synthetic routes for test use', () {
      final engine = RouteDiscoveryEngine();
      final testRoutes = engine.generateTestRoutes(_center);
      expect(testRoutes, hasLength(2));
      expect(testRoutes.first.id, startsWith('test_route_'));
    });

    test('23. Test routes have valid GPS points', () {
      final engine = RouteDiscoveryEngine();
      final testRoutes = engine.generateTestRoutes(_center);
      for (final route in testRoutes) {
        expect(route.points, isNotEmpty);
        for (final pt in route.points) {
          expect(pt.latitude.isFinite, isTrue);
          expect(pt.longitude.isFinite, isTrue);
        }
      }
    });
  });

  // 8. RouteCache TTL caching ────────────────────────────────────────────────

  group('RouteCache TTL caching', () {
    test('24. Returns null for missing key', () {
      expect(RouteCache.instance.get<List<int>>('missing'), isNull);
    });

    test('25. Stores and retrieves value', () {
      RouteCache.instance.set('k1', [10, 20, 30]);
      expect(RouteCache.instance.get<List<int>>('k1'), equals([10, 20, 30]));
    });

    test('26. Invalidate removes key', () {
      RouteCache.instance.set('k2', 'hello');
      RouteCache.instance.invalidate('k2');
      expect(RouteCache.instance.get<String>('k2'), isNull);
    });
  });
}
