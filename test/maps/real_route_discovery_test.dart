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
  _FakeValhalla(
    this._route, {
    this.exceptionToThrow,
    this.routeResolver,
  });

  final ValhallaRoute? _route;
  final Exception? exceptionToThrow;
  final ValhallaRoute? Function(LatLng origin, List<LatLng> waypoints)?
      routeResolver;

  @override
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
  }) async {
    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    if (routeResolver != null) {
      return routeResolver!(origin, waypoints);
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
  ValhallaRoute? Function(LatLng, List<LatLng>)? routeResolver,
}) =>
    _RealServiceStub(
      overpass: _FakeOverpass(places, exceptionToThrow: overpassError),
      valhalla: _FakeValhalla(
        valhallaRoute,
        exceptionToThrow: valhallaError,
        routeResolver: routeResolver,
      ),
    );

// ─── Sample fixture data ─────────────────────────────────────────────────────

const _center = LatLng(51.505, -0.090); // London

OverpassPlace _park(int id, String name, double lat, double lon,
        {bool isNamed = true, Map<String, String>? tags}) =>
    OverpassPlace(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      tags: tags ?? const {'leisure': 'park'},
      isNamed: isNamed,
    );

/// Genuine polygon loop circuit with wide lateral separation
final _genuineLoopRoute = ValhallaRoute(
  points: [
    const LatLng(51.505, -0.090),
    const LatLng(51.507, -0.086),
    const LatLng(51.509, -0.084),
    const LatLng(51.512, -0.085),
    const LatLng(51.514, -0.090),
    const LatLng(51.512, -0.095),
    const LatLng(51.509, -0.096),
    const LatLng(51.507, -0.094),
    const LatLng(51.506, -0.092),
    const LatLng(51.505, -0.090),
  ],
  distanceMeters: 2800,
  durationSeconds: 1980,
);

/// Retraced out-and-back route traversing the same street coordinates
final _retracedOutAndBackRoute = ValhallaRoute(
  points: [
    const LatLng(51.505, -0.090),
    const LatLng(51.507, -0.090),
    const LatLng(51.509, -0.090),
    const LatLng(51.511, -0.090),
    const LatLng(51.513, -0.090),
    const LatLng(51.515, -0.090),
    const LatLng(51.513, -0.090),
    const LatLng(51.511, -0.090),
    const LatLng(51.509, -0.090),
    const LatLng(51.507, -0.090),
    const LatLng(51.505, -0.090),
  ],
  distanceMeters: 2200,
  durationSeconds: 1600,
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

    test('9b. Multi-waypoint routing propagates RouteRateLimitException without retrying fallback', () async {
      final p1 = _park(1, 'Hyde Park', 51.507, -0.095);
      final p2 = _park(2, 'Kensington Gardens', 51.503, -0.085);

      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [p1, p2],
          valhallaRoute: null,
          valhallaError: const RouteRateLimitException(),
        ),
      );

      expect(
        () => engine.discoverRoutes(center: _center),
        throwsA(isA<RouteRateLimitException>()),
      );
    });

    test('9c. Multi-waypoint routing propagates RouteNetworkException without retrying fallback', () async {
      final p1 = _park(1, 'Hyde Park', 51.507, -0.095);
      final p2 = _park(2, 'Kensington Gardens', 51.503, -0.085);

      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [p1, p2],
          valhallaRoute: null,
          valhallaError: const RouteNetworkException(),
        ),
      );

      expect(
        () => engine.discoverRoutes(center: _center),
        throwsA(isA<RouteNetworkException>()),
      );
    });
  });

  // 3. Valhalla polyline decoder & geometry loop analysis ──────────────────────

  group('Valhalla polyline decoder & genuine loop geometry analysis', () {
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

    test('11. Detects retraced out-and-back route correctly via geometry', () {
      expect(
        _retracedOutAndBackRoute.isLoop,
        isFalse,
        reason: 'Retraced out-and-back must not be labeled as loop',
      );
    });

    test('12. Detects genuine polygon circuit loop correctly via geometry', () {
      expect(
        _genuineLoopRoute.isLoop,
        isTrue,
        reason: 'Divergent circular path must be verified as genuine loop',
      );
    });

    test('13. Prevents incorrect loop classification when start and end do not close', () {
      final openPath = ValhallaRoute(
        points: [
          const LatLng(51.505, -0.090),
          const LatLng(51.507, -0.088),
          const LatLng(51.509, -0.086),
          const LatLng(51.511, -0.085),
          const LatLng(51.513, -0.088),
          const LatLng(51.515, -0.092),
          const LatLng(51.517, -0.096),
          const LatLng(51.519, -0.098),
          const LatLng(51.521, -0.100),
          const LatLng(51.523, -0.102),
        ],
        distanceMeters: 2500,
        durationSeconds: 1800,
      );
      expect(openPath.isLoop, isFalse);
    });

    test('14. Production engine never marks route as loop when Valhalla returns retraced geometry', () async {
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
          valhallaRoute: _retracedOutAndBackRoute,
        ),
      );

      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isNotEmpty);
      expect(routes.first.isLoop, isFalse);
      expect(routes.first.name, contains('Out & Back'));
      expect(routes.first.name, isNot(endsWith('Loop')));
    });

    test('14b. Route classified as Out & Back with two named places never ends in Loop', () async {
      final p1 = _park(1, 'Regents Park', 51.507, -0.095);
      final p2 = _park(2, 'Primrose Hill', 51.508, -0.085);

      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [p1, p2],
          valhallaRoute: _retracedOutAndBackRoute, // Returns isLoop = false
        ),
      );

      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isNotEmpty);
      expect(routes.first.isLoop, isFalse);
      expect(routes.first.name, equals('Regents Park & Primrose Hill Out & Back'));
      expect(routes.first.name.endsWith('Loop'), isFalse);
    });

    test('14c. Fallback to single waypoint does not include unused second location in name or ID', () async {
      final p1 = _park(10, 'Greenwich Park', 51.507, -0.095);
      final p2 = _park(20, 'Blackheath Common', 51.503, -0.085);

      final singleWaypointRoute = ValhallaRoute(
        points: _retracedOutAndBackRoute.points,
        distanceMeters: 2000,
        durationSeconds: 1500,
      );

      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [p1, p2],
          valhallaRoute: null,
          routeResolver: (origin, waypoints) {
            // Multi-point fails (returns null), single waypoint succeeds
            if (waypoints.length > 2) return null;
            return singleWaypointRoute;
          },
        ),
      );

      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isNotEmpty);
      final route = routes.first;

      // Must not include p2 (Blackheath Common) anywhere
      expect(route.name, equals('Greenwich Park Out & Back'));
      expect(route.name.contains('Blackheath Common'), isFalse);
      expect(route.id, equals('osm_10_0'));
      expect(route.description.contains('Blackheath Common'), isFalse);
    });
  });

  // 4. Activity type suitability & filtering ─────────────────────────────────

  group('Activity type suitability and RouteFilter regression', () {
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

    test('15. Paved walking route is suitable for both walking and running', () {
      expect(walkRoute.isSuitableFor(OutdoorActivityType.walking), isTrue);
      expect(walkRoute.isSuitableFor(OutdoorActivityType.running), isTrue);
      expect(walkRoute.isSuitableFor(OutdoorActivityType.hiking), isFalse);
    });

    test('16. Rugged trail hike is not suitable for running', () {
      expect(trailHike.isSuitableFor(OutdoorActivityType.hiking), isTrue);
      expect(trailHike.isSuitableFor(OutdoorActivityType.running), isFalse);
    });

    test('17. RouteFilter with running includes paved pedestrian routes', () {
      const runFilter = RouteFilter(activityType: OutdoorActivityType.running);
      expect(runFilter.matches(walkRoute), isTrue);
      expect(runFilter.matches(trailHike), isFalse);
    });

    test('18. RouteFilter with hiking includes only genuine trail routes', () {
      const hikeFilter = RouteFilter(activityType: OutdoorActivityType.hiking);
      expect(hikeFilter.matches(trailHike), isTrue);
      expect(hikeFilter.matches(walkRoute), isFalse);
    });
  });

  // 5. Metadata accuracy & estimated difficulty ──────────────────────────────

  group('Route metadata accuracy & estimate labeling', () {
    test('19. Formats unavailable elevation as -- without claiming +0m flat', () {
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

    test('20. Clearly labels estimated difficulty vs verified OSM difficulty', () {
      const estimatedRoute = SavedRoute(
        id: 'r_est',
        name: 'Neighborhood Walk',
        activityType: OutdoorActivityType.walking,
        distanceMeters: 2000,
        estimatedDurationSeconds: 1400,
        difficulty: RouteDifficulty.easy,
        isDifficultyEstimated: true,
        points: [],
      );
      const verifiedRoute = SavedRoute(
        id: 'r_ver',
        name: 'Alpine Path',
        activityType: OutdoorActivityType.hiking,
        distanceMeters: 8000,
        estimatedDurationSeconds: 7000,
        difficulty: RouteDifficulty.hard,
        isDifficultyEstimated: false,
        points: [],
      );

      expect(estimatedRoute.formattedDifficulty, equals('Est. Easy'));
      expect(verifiedRoute.formattedDifficulty, equals('Hard'));
    });
  });

  // 6. Real discovery flow with deduplication & unnamed paths ────────────────

  group('RealRouteDiscoveryService deduplication and unnamed paths', () {
    test('21. Returns empty list when Overpass returns no places', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(places: [], valhallaRoute: null),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isEmpty);
    });

    test('22. Allows multiple unnamed routes with identical display names when geometry differs', () async {
      final footwayNorth = OverpassPlace(
        id: 201,
        name: 'Mapped Footway',
        lat: 51.520,
        lon: -0.090,
        tags: const {'highway': 'footway'},
        isNamed: false,
      );
      final footwaySouth = OverpassPlace(
        id: 202,
        name: 'Mapped Footway',
        lat: 51.490,
        lon: -0.090,
        tags: const {'highway': 'footway'},
        isNamed: false,
      );

      final routeNorth = ValhallaRoute(
        points: [
          const LatLng(51.505, -0.090),
          const LatLng(51.510, -0.090),
          const LatLng(51.515, -0.090),
          const LatLng(51.520, -0.090),
          const LatLng(51.505, -0.090),
        ],
        distanceMeters: 3300,
        durationSeconds: 2400,
      );

      final routeSouth = ValhallaRoute(
        points: [
          const LatLng(51.505, -0.090),
          const LatLng(51.500, -0.090),
          const LatLng(51.495, -0.090),
          const LatLng(51.490, -0.090),
          const LatLng(51.505, -0.090),
        ],
        distanceMeters: 3300,
        durationSeconds: 2400,
      );

      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [footwayNorth, footwaySouth],
          valhallaRoute: null,
          routeResolver: (origin, waypoints) {
            if (waypoints.first.latitude > 51.51) return routeNorth;
            return routeSouth;
          },
        ),
      );

      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, hasLength(2));
      expect(routes[0].name, equals(routes[1].name));
    });

    test('23. Removes duplicate geometry in the same corridor with similar distance', () async {
      final p1 = _park(301, 'Corridor A', 51.506, -0.091);
      final p2 = _park(302, 'Corridor B', 51.506, -0.0915);

      final duplicateRouteA = ValhallaRoute(
        points: [
          const LatLng(51.505, -0.090),
          const LatLng(51.506, -0.091),
          const LatLng(51.507, -0.092),
          const LatLng(51.506, -0.091),
          const LatLng(51.505, -0.090),
        ],
        distanceMeters: 1500,
        durationSeconds: 1000,
      );

      final duplicateRouteB = ValhallaRoute(
        points: [
          const LatLng(51.505, -0.090),
          const LatLng(51.506, -0.091),
          const LatLng(51.507, -0.092),
          const LatLng(51.506, -0.091),
          const LatLng(51.505, -0.090),
        ],
        distanceMeters: 1510,
        durationSeconds: 1010,
      );

      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [p1, p2],
          valhallaRoute: null,
          routeResolver: (origin, waypoints) =>
              waypoints.first.longitude == -0.091 ? duplicateRouteA : duplicateRouteB,
        ),
      );

      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, hasLength(1), reason: 'Duplicate geometry must be deduplicated');
    });

    test('24. Filters routes shorter than 300 meters', () async {
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

  // 7. Backward compatibility with older stored routes ───────────────────────

  group('Backward compatibility with older SavedRoute JSON', () {
    test('25. Old saved-route JSON missing is_difficulty_estimated retains estimated classification', () {
      final oldJsonWithoutIsLoop = {
        'id': 'legacy_route_001',
        'name': 'Old Track',
        'activity_type': 'walk',
        'distance_meters': 2000.0,
        'estimated_duration_sec': 1400,
        'difficulty': 'easy',
        'points': <dynamic>[],
        'description': 'Legacy walk',
      };

      final route = SavedRoute.fromJson(oldJsonWithoutIsLoop);
      expect(route.id, equals('legacy_route_001'));
      expect(route.isLoop, isFalse, reason: 'Old routes without is_loop must default to false');
      expect(route.surfaceType, equals(RouteSurface.unknown));
      // Missing is_difficulty_estimated defaults to true to preserve estimated classification
      expect(route.isDifficultyEstimated, isTrue);
      expect(route.formattedDifficulty, equals('Est. Easy'));
    });

    test('25b. SavedRoute JSON with explicit is_difficulty_estimated=false retains verified rating', () {
      final verifiedJson = {
        'id': 'verified_route_001',
        'name': 'Verified Alpine Ridge',
        'activity_type': 'hike',
        'distance_meters': 12000.0,
        'estimated_duration_sec': 10000,
        'difficulty': 'hard',
        'is_difficulty_estimated': false,
        'points': <dynamic>[],
      };

      final route = SavedRoute.fromJson(verifiedJson);
      expect(route.isDifficultyEstimated, isFalse);
      expect(route.formattedDifficulty, equals('Hard'));
    });

    test('26. Old saved-route JSON without surface_type parses safely without error', () {
      final oldJsonWithoutSurface = {
        'id': 'legacy_route_002',
        'name': 'Historic Park Circuit',
        'activity_type': 'run',
        'distance_meters': 5000.0,
        'estimated_duration_sec': 1800,
        'points': <dynamic>[],
      };

      final route = SavedRoute.fromJson(oldJsonWithoutSurface);
      expect(route.id, equals('legacy_route_002'));
      expect(route.surfaceType, equals(RouteSurface.unknown));
      expect(route.activityType, equals(OutdoorActivityType.running));
    });
  });

  // 8. RouteDiscoveryEngine test fixtures ────────────────────────────────────

  group('RouteDiscoveryEngine test fixtures', () {
    test('27. generateTestRoutes returns synthetic routes for test use', () {
      final engine = RouteDiscoveryEngine();
      final testRoutes = engine.generateTestRoutes(_center);
      expect(testRoutes, hasLength(2));
      expect(testRoutes.first.id, startsWith('test_route_'));
    });

    test('28. Test routes have valid GPS points', () {
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

  // 9. RouteCache TTL caching ────────────────────────────────────────────────

  group('RouteCache TTL caching', () {
    test('29. Returns null for missing key', () {
      expect(RouteCache.instance.get<List<int>>('missing'), isNull);
    });

    test('30. Stores and retrieves value', () {
      RouteCache.instance.set('k1', [10, 20, 30]);
      expect(RouteCache.instance.get<List<int>>('k1'), equals([10, 20, 30]));
    });

    test('31. Invalidate removes key', () {
      RouteCache.instance.set('k2', 'hello');
      RouteCache.instance.invalidate('k2');
      expect(RouteCache.instance.get<String>('k2'), isNull);
    });
  });
}
