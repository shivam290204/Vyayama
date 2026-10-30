// test/maps/real_route_discovery_test.dart

import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/real_route_discovery_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/services/route_discovery_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// ─── Stub Overpass ──────────────────────────────────────────────────────────

class _FakeOverpass extends OverpassService {
  _FakeOverpass(this._places) : super(cache: RouteCache.instance);
  final List<OverpassPlace> _places;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
  }) async =>
      _places;
}

// ─── Stub Valhalla ──────────────────────────────────────────────────────────

class _FakeValhalla extends ValhallaService {
  _FakeValhalla(this._route);
  final ValhallaRoute? _route;

  @override
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
  }) async =>
      _route;
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
}) =>
    _RealServiceStub(
      overpass: _FakeOverpass(places),
      valhalla: _FakeValhalla(valhallaRoute),
    );

// ─── Sample fixture data ─────────────────────────────────────────────────────

const _center = LatLng(51.505, -0.09); // London

OverpassPlace _park(int id, String name, double lat, double lon) =>
    OverpassPlace(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      tags: const {'leisure': 'park'},
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
);

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUp(() => RouteCache.instance.clear());

  // 1. Overpass response parsing ─────────────────────────────────────────────

  group('OverpassPlace classification', () {
    test('1. isPark true for leisure=park', () {
      const place = OverpassPlace(
        id: 1,
        name: 'Riverside Park',
        lat: 51.505,
        lon: -0.09,
        tags: {'leisure': 'park'},
      );
      expect(place.isPark, isTrue);
      expect(place.isTrail, isFalse);
    });

    test('2. isTrail true for highway=footway', () {
      const place = OverpassPlace(
        id: 2,
        name: 'River Walk',
        lat: 51.505,
        lon: -0.09,
        tags: {'highway': 'footway'},
      );
      expect(place.isTrail, isTrue);
      expect(place.isPark, isFalse);
    });

    test('3. isTrail true for route=hiking', () {
      const place = OverpassPlace(
        id: 3,
        name: 'Hill Trail',
        lat: 51.505,
        lon: -0.09,
        tags: {'route': 'hiking'},
      );
      expect(place.isTrail, isTrue);
    });

    test('4. Empty name place is constructable', () {
      // _parseOverpassResponse filters out empty names at source
      const place = OverpassPlace(
        id: 4,
        name: '',
        lat: 51.5,
        lon: -0.09,
        tags: {},
      );
      expect(place.name.isEmpty, isTrue);
    });
  });

  // 2. Valhalla polyline decoder ─────────────────────────────────────────────

  group('Valhalla polyline decoder', () {
    test('5. Parses valid trip JSON with correct distance and duration', () {
      final service = ValhallaService();
      // Minimal valid trip JSON — shape is a simple encoded polyline
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

    test('6. Returns null for missing trip in JSON', () {
      final service = ValhallaService();
      final parsed = service.testParseRoute('{"error": "no route"}');
      expect(parsed, isNull);
    });

    test('7. Returns null for malformed JSON', () {
      final service = ValhallaService();
      final parsed = service.testParseRoute('not-json!!');
      expect(parsed, isNull);
    });
  });

  // 3. Haversine distance ────────────────────────────────────────────────────

  group('Haversine distance calculation', () {
    test('8. Known distance between two coordinates', () {
      const a = LatLng(51.5074, -0.1278); // London
      const b = LatLng(48.8566, 2.3522); // Paris
      final dist = haversineDistance(a, b);
      // Approx 343 km
      expect(dist / 1000, inInclusiveRange(330.0, 360.0));
    });

    test('9. Distance between same point is zero', () {
      const a = LatLng(51.5, -0.1);
      expect(haversineDistance(a, a), closeTo(0.0, 0.01));
    });
  });

  // 4. Real discovery with stubs ─────────────────────────────────────────────

  group('RealRouteDiscoveryService with stubs', () {
    test('10. Returns empty list when Overpass returns no places', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(places: [], valhallaRoute: null),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isEmpty);
    });

    test('11. Returns empty list when Valhalla returns null', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [_park(1, 'Riverside Park', 51.506, -0.091)],
          valhallaRoute: null,
        ),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isEmpty);
    });

    test('12. Returns real route when both services succeed', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [_park(1, 'Riverside Park', 51.506, -0.091)],
          valhallaRoute: _validRoute,
        ),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, hasLength(1));
      final route = routes.first;
      expect(route.name, equals('Riverside Park'));
      expect(route.distanceMeters, closeTo(2800, 1));
      expect(route.points, isNotEmpty);
    });

    test('13. Route name comes from OSM place name, not fictional', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [_park(42, 'Victoria Gardens', 51.506, -0.091)],
          valhallaRoute: _validRoute,
        ),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes.first.name, equals('Victoria Gardens'));
      // Must not be any of the old fake names
      expect(routes.first.name, isNot(contains('Greenway')));
      expect(routes.first.name, isNot(contains('Pine Hill')));
      expect(routes.first.name, isNot(contains('Metropolitan')));
    });

    test('14. Deduplicates routes with nearly identical distance', () async {
      // Two parks at similar distance — Valhalla returns same 2800m both times
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [
            _park(1, 'Park A', 51.506, -0.091),
            _park(2, 'Park B', 51.506, -0.092),
          ],
          valhallaRoute: _validRoute,
        ),
      );
      final routes = await engine.discoverRoutes(center: _center);
      // Because both return distance 2800m (within 150m threshold), only 1 kept
      expect(routes.length, lessThanOrEqualTo(1));
    });

    test('15. Filters routes too short (< 300m)', () async {
      final shortRoute = ValhallaRoute(
        points: [
          const LatLng(51.505, -0.09),
          const LatLng(51.506, -0.09),
        ],
        distanceMeters: 100,
        durationSeconds: 60,
      );
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [_park(1, 'Tiny Square', 51.506, -0.091)],
          valhallaRoute: shortRoute,
        ),
      );
      final routes = await engine.discoverRoutes(center: _center);
      expect(routes, isEmpty);
    });

    test('16. RouteFilter.activityType is applied to discovered routes',
        () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [_park(1, 'Central Park', 51.506, -0.091)],
          valhallaRoute: _validRoute,
        ),
      );
      const filter = RouteFilter(activityType: OutdoorActivityType.running);
      final routes = await engine.discoverRoutes(
        center: _center,
        filter: filter,
      );
      // The park place will generate a walking route, which won't match running filter
      expect(
        routes.where((r) => r.activityType == OutdoorActivityType.walking),
        isEmpty,
      );
    });

    test('17. Empty list when no places match filter distance', () async {
      final engine = RouteDiscoveryEngine(
        realService: _makeService(
          places: [_park(1, 'Far Park', 51.506, -0.091)],
          valhallaRoute: _validRoute,
        ),
      );
      const filter = RouteFilter(maxDistanceKm: 0.5); // 500m max, route is 2.8km
      final routes =
          await engine.discoverRoutes(center: _center, filter: filter);
      expect(routes, isEmpty);
    });
  });

  // 5. RouteDiscoveryEngine test fixtures ────────────────────────────────────

  group('RouteDiscoveryEngine test fixtures', () {
    test('18. generateTestRoutes returns synthetic routes for test use', () {
      final engine = RouteDiscoveryEngine();
      final testRoutes = engine.generateTestRoutes(_center);
      expect(testRoutes, hasLength(2));
      expect(testRoutes.first.id, startsWith('test_route_'));
    });

    test('19. Test routes have valid GPS points', () {
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

  // 6. RouteCache ────────────────────────────────────────────────────────────

  group('RouteCache TTL caching', () {
    test('20. Returns null for missing key', () {
      expect(RouteCache.instance.get<List<int>>('missing'), isNull);
    });

    test('21. Stores and retrieves value', () {
      RouteCache.instance.set('k1', [1, 2, 3]);
      expect(RouteCache.instance.get<List<int>>('k1'), equals([1, 2, 3]));
    });

    test('22. Invalidate removes key', () {
      RouteCache.instance.set('k2', 'hello');
      RouteCache.instance.invalidate('k2');
      expect(RouteCache.instance.get<String>('k2'), isNull);
    });
  });
}
