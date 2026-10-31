import 'dart:async';

import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';
import 'package:fitbuddy/features/maps/data/services/nominatim_service.dart';
import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/real_route_discovery_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_discovery_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  setUp(() {
    RouteCache.instance.clear();
    MapApiConfig.resetWarningFlagForTesting();
  });

  // ---------------------------------------------------------------------------
  // 1. Centralized MapApiConfig
  // ---------------------------------------------------------------------------
  group('MapApiConfig Centralization Tests', () {
    test('1. Default endpoints are non-empty and well-formed', () {
      expect(MapApiConfig.defaultTileUrl, contains('{z}/{x}/{y}'));
      expect(MapApiConfig.defaultOverpassUrl, startsWith('https://'));
      expect(MapApiConfig.defaultOverpassMirrors, hasLength(greaterThanOrEqualTo(2)));
      expect(MapApiConfig.defaultValhallaUrl, startsWith('https://'));
      expect(MapApiConfig.defaultNominatimUrl, startsWith('https://'));
    });

    test('2. User-Agent complies with Vyayama application branding policy', () {
      expect(MapApiConfig.defaultUserAgent, contains('Vyayama'));
      expect(MapApiConfig.defaultUserAgent, contains('com.vyayama.fitbuddy'));
      expect(MapApiConfig.userAgent, equals(MapApiConfig.defaultUserAgent));
    });

    test('3. Overpass endpoints list includes primary endpoint and mirrors', () {
      final endpoints = MapApiConfig.overpassEndpoints;
      expect(endpoints, isNotEmpty);
      expect(endpoints.first, equals(MapApiConfig.overpassUrl));
      expect(endpoints, contains('https://overpass-api.de/api/interpreter'));
    });

    test('4. Correctly identifies public community demo endpoints', () {
      expect(MapApiConfig.isUsingPublicTileEndpoint, isTrue);
      expect(MapApiConfig.isUsingPublicOverpassEndpoint, isTrue);
      expect(MapApiConfig.isUsingPublicValhallaEndpoint, isTrue);
      expect(MapApiConfig.isUsingPublicNominatimEndpoint, isTrue);
    });

    test('5. Release mode warning executes safely', () {
      expect(() => MapApiConfig.warnIfPublicEndpointsInRelease(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. RouteCache LRU Eviction & Geographic Key Isolation
  // ---------------------------------------------------------------------------
  group('RouteCache LRU Eviction & Geographic Isolation Tests', () {
    test('6. Evicts least recently used item when maxEntries is exceeded', () {
      final cache = RouteCache(maxEntries: 3, ttl: const Duration(minutes: 5));

      cache.set('key1', 'value1');
      cache.set('key2', 'value2');
      cache.set('key3', 'value3');

      expect(cache.size, equals(3));
      expect(cache.get('key1'), equals('value1')); // Key1 accessed, now MRU

      // Add 4th key: should evict key2 (oldest / LRU)
      cache.set('key4', 'value4');

      expect(cache.size, equals(3));
      expect(cache.get('key1'), equals('value1'));
      expect(cache.get('key2'), isNull); // Evicted!
      expect(cache.get('key3'), equals('value3'));
      expect(cache.get('key4'), equals('value4'));
    });

    test('7. Expires entries exceeding TTL', () async {
      final cache = RouteCache(
        maxEntries: 10,
        ttl: const Duration(milliseconds: 50),
      );

      cache.set('tempKey', 'tempValue');
      expect(cache.get('tempKey'), equals('tempValue'));

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(cache.get('tempKey'), isNull);
      expect(cache.size, equals(0));
    });

    test('8. buildAreaKey produces identical keys for coordinates within ~100m', () {
      const p1 = LatLng(28.71450, 77.16820);
      const p2 = LatLng(28.71454, 77.16824); // ~5m offset

      final key1 = RouteCache.buildAreaKey(center: p1, radiusMeters: 5000);
      final key2 = RouteCache.buildAreaKey(center: p2, radiusMeters: 5000);

      expect(key1, equals(key2));
    });

    test('9. buildAreaKey isolates distinct coordinates and filters', () {
      const p1 = LatLng(28.7145, 77.1682);
      const p2 = LatLng(28.7400, 77.2000); // Several km away

      final key1 = RouteCache.buildAreaKey(center: p1, radiusMeters: 5000);
      final key2 = RouteCache.buildAreaKey(center: p2, radiusMeters: 5000);
      final key3 = RouteCache.buildAreaKey(
        center: p1,
        radiusMeters: 5000,
        filter: const RouteFilter(activityType: OutdoorActivityType.hiking),
      );

      expect(key1, isNot(equals(key2)));
      expect(key1, isNot(equals(key3)));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Overpass Accessible Tag Filtering & Validation
  // ---------------------------------------------------------------------------
  group('Overpass Tag Filtering & Coordinate Validation Tests', () {
    test('10. OverpassPlace.isAccessible correctly detects accessible paths', () {
      const publicPark = OverpassPlace(
        id: 1,
        name: 'Public Park',
        lat: 51.5,
        lon: -0.1,
        tags: {'leisure': 'park'},
      );
      expect(publicPark.isAccessible, isTrue);

      const privateEstate = OverpassPlace(
        id: 2,
        name: 'Private Estate',
        lat: 51.5,
        lon: -0.1,
        tags: {'leisure': 'park', 'access': 'private'},
      );
      expect(privateEstate.isAccessible, isFalse);

      const noAccessPath = OverpassPlace(
        id: 3,
        name: 'Restricted Path',
        lat: 51.5,
        lon: -0.1,
        tags: {'highway': 'footway', 'access': 'no'},
      );
      expect(noAccessPath.isAccessible, isFalse);

      const noFootway = OverpassPlace(
        id: 4,
        name: 'Motorway Service',
        lat: 51.5,
        lon: -0.1,
        tags: {'highway': 'track', 'foot': 'no'},
      );
      expect(noFootway.isAccessible, isFalse);
    });

    test('11. parseOverpassResponse rejects out-of-bounds latitude and longitude', () {
      final service = OverpassService();
      const mockJson = '''
{
  "elements": [
    {
      "type": "way",
      "id": 101,
      "center": { "lat": 95.0, "lon": 77.1 },
      "tags": { "highway": "footway", "name": "Invalid North" }
    },
    {
      "type": "way",
      "id": 102,
      "center": { "lat": 28.7, "lon": 200.0 },
      "tags": { "highway": "footway", "name": "Invalid East" }
    },
    {
      "type": "way",
      "id": 103,
      "center": { "lat": 28.7145, "lon": 77.1682 },
      "tags": { "highway": "footway", "name": "Valid Delhi Path" }
    }
  ]
}
''';
      final places = service.parseOverpassResponse(mockJson);
      expect(places, hasLength(1));
      expect(places.first.id, equals(103));
      expect(places.first.name, equals('Valid Delhi Path'));
    });

    test('12. cancelActiveRequests completes without throwing', () {
      final service = OverpassService();
      expect(() => service.cancelActiveRequests(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Nominatim Throttling, LRU Caching & Request Joining
  // ---------------------------------------------------------------------------
  group('Nominatim Service Throttling & Deduplication Tests', () {
    test('13. LRU cache returns cached places on subsequent queries', () async {
      final cache = RouteCache();
      final service = NominatimService(cache: cache);

      const sampleJson = '''
[
  {
    "osm_id": 999,
    "lat": "28.7145",
    "lon": "77.1682",
    "class": "leisure",
    "type": "park",
    "name": "Cached Shalimar Garden"
  }
]
''';
      final places = NominatimService.parseNominatimPlaces(sampleJson);
      final cacheKey = RouteCache.buildNominatimNearbyKey(
        const LatLng(28.7145, 77.1682),
        5000,
      );
      cache.set(cacheKey, places);

      // Now query findNearbyPlaces - should read directly from cache without hitting network
      final cachedPlaces = await service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 5000,
      );

      expect(cachedPlaces, hasLength(1));
      expect(cachedPlaces.first.name, equals('Cached Shalimar Garden'));
    });

    test('14. cancelActiveRequests completes without throwing', () {
      final service = NominatimService();
      expect(() => service.cancelActiveRequests(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Valhalla Routing Validation & Cancellation
  // ---------------------------------------------------------------------------
  group('Valhalla Routing Validation & Cancellation Tests', () {
    test('15. testParseRoute rejects invalid non-finite or out-of-bounds coordinates', () {
      final service = ValhallaService();
      // Polyline with points beyond [-90, 90] / [-180, 180] or empty legs
      const emptyTrip = '''
{
  "trip": {
    "summary": { "length": 0.0, "time": 0 },
    "legs": []
  }
}
''';
      expect(service.testParseRoute(emptyTrip), isNull);
    });

    test('16. cancelActiveRequests completes without throwing', () {
      final service = ValhallaService();
      expect(() => service.cancelActiveRequests(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Pipeline Concurrency, Max Candidates & Superseded Requests
  // ---------------------------------------------------------------------------
  group('RealRouteDiscoveryService Concurrency & Pipeline Tests', () {
    test('17. Bounds candidates to maximum 8 waypoints', () async {
      int valhallaCallCount = 0;

      final dummyPlaces = List.generate(
        20,
        (i) => OverpassPlace(
          id: i + 1,
          name: 'Park $i',
          lat: 51.505 + (i * 0.001),
          lon: -0.090 + (i * 0.001),
          tags: {'leisure': 'park'},
        ),
      );

      final valhalla = _CountingValhalla(
        onRoute: () => valhallaCallCount++,
      );

      final service = RealRouteDiscoveryService(
        overpass: _StaticOverpass(dummyPlaces),
        valhalla: valhalla,
        nominatim: _StaticNominatim([]),
      );

      final routes = await service.discoverRoutes(
        center: const LatLng(51.505, -0.090),
      );

      // Max 8 candidates are selected
      expect(valhallaCallCount, lessThanOrEqualTo(8));
      expect(routes.length, lessThanOrEqualTo(5)); // max 5 saved routes returned
    });

    test('18. Enforces maximum concurrency of 2 for Valhalla requests', () async {
      int maxConcurrent = 0;
      int currentConcurrent = 0;

      final dummyPlaces = List.generate(
        6,
        (i) => OverpassPlace(
          id: i + 1,
          name: 'Green $i',
          lat: 51.505 + (i * 0.002),
          lon: -0.090 + (i * 0.002),
          tags: {'leisure': 'park'},
        ),
      );

      final valhalla = _DelayedValhalla(
        delay: const Duration(milliseconds: 30),
        onStart: () {
          currentConcurrent++;
          if (currentConcurrent > maxConcurrent) {
            maxConcurrent = currentConcurrent;
          }
        },
        onEnd: () {
          currentConcurrent--;
        },
      );

      final service = RealRouteDiscoveryService(
        overpass: _StaticOverpass(dummyPlaces),
        valhalla: valhalla,
        nominatim: _StaticNominatim([]),
      );

      await service.discoverRoutes(
        center: const LatLng(51.505, -0.090),
      );

      // Maximum concurrent Valhalla requests must not exceed 2
      expect(maxConcurrent, lessThanOrEqualTo(2));
    });

    test('19. Discards results of superseded searches when a newer search begins', () async {
      final completer1 = Completer<List<OverpassPlace>>();
      final completer2 = Completer<List<OverpassPlace>>();

      final overpass = _ControllableOverpass([completer1, completer2]);

      final service = RealRouteDiscoveryService(
        overpass: overpass,
        valhalla: _FakeValhalla(null),
        nominatim: _StaticNominatim([]),
      );

      // First search begins
      final future1 = service.discoverRoutes(
        center: const LatLng(51.505, -0.090),
      );

      // Second search begins immediately at a different center (supersedes search 1)
      final future2 = service.discoverRoutes(
        center: const LatLng(28.7145, 77.1682),
      );

      // Complete search 1
      completer1.complete([
        const OverpassPlace(
          id: 1,
          name: 'Old Search Park',
          lat: 51.505,
          lon: -0.090,
          tags: {'leisure': 'park'},
        ),
      ]);

      // Complete search 2
      completer2.complete([
        const OverpassPlace(
          id: 2,
          name: 'New Search Park',
          lat: 28.7145,
          lon: 77.1682,
          tags: {'leisure': 'park'},
        ),
      ]);

      final result1 = await future1;
      final result2 = await future2;

      // Superseded search 1 must return empty list (discarded)
      expect(result1, isEmpty);
      expect(result2, isEmpty); // No route returned by fake Valhalla
    });

    test('20. In-flight discovery joining prevents duplicate pipeline executions', () async {
      int overpassExecutions = 0;

      final overpass = _CountingOverpass(
        onQuery: () => overpassExecutions++,
        delay: const Duration(milliseconds: 40),
      );

      final service = RealRouteDiscoveryService(
        overpass: overpass,
        valhalla: _FakeValhalla(null),
        nominatim: _StaticNominatim([]),
      );

      const center = LatLng(51.505, -0.090);

      // Fire 2 concurrent identical requests
      final future1 = service.discoverRoutes(center: center);
      final future2 = service.discoverRoutes(center: center);

      final results = await Future.wait([future1, future2]);

      expect(overpassExecutions, equals(1));
      expect(results[0], equals(results[1]));
    });

    test('21. cancelCurrentDiscovery invalidates active generation and network requests', () {
      final service = RealRouteDiscoveryService(
        overpass: _StaticOverpass([]),
        valhalla: _FakeValhalla(null),
        nominatim: _StaticNominatim([]),
      );

      expect(() => service.cancelCurrentDiscovery(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. RouteDiscoverySheet UI Error States & Interactions
  // ---------------------------------------------------------------------------
  group('RouteDiscoverySheet Error States Widget Tests', () {

    testWidgets('22. Renders Rate Limit error view when RouteRateLimitException occurs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Future.error(const RouteRateLimitException()),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rate Limit Reached'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('23. Renders Connection Timed Out error view on network timeout',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Future.error(
                    const RouteNetworkException('Request timed out while contacting host'),
                  ),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connection Timed Out'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
    });

    testWidgets('24. Renders No Internet Connection error view on network failure',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Future.error(
                    const RouteNetworkException('SocketException: Failed to reach host'),
                  ),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('25. Renders Map Data Temporarily Unavailable on OverpassServiceException',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Future.error(const OverpassServiceException('504 Gateway Timeout')),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Map Data Temporarily Unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('26. Renders Routing Engine Unavailable on ValhallaRoutingException',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Future.error(const ValhallaRoutingException('Service down')),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Routing Engine Unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.alt_route_rounded), findsOneWidget);
    });

    testWidgets('27. Empty routes list displays No mapped routes found nearby',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith((ref) => <SavedRoute>[]),
                userLocationStateProvider.overrideWith(
                  (ref) => UserLocationState(
                    status: UserLocationStatus.available,
                    position: const LatLng(51.5, -0.1),
                  ),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No mapped routes found nearby.'), findsOneWidget);
      expect(find.byIcon(Icons.explore_off_rounded), findsOneWidget);
    });
  });
}

// -----------------------------------------------------------------------------
// Test Helpers & Mock Classes
// -----------------------------------------------------------------------------

class _StaticOverpass extends OverpassService {
  _StaticOverpass(this._places);
  final List<OverpassPlace> _places;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
  }) async =>
      _places;
}

class _StaticNominatim extends NominatimService {
  _StaticNominatim(this._places);
  final List<OverpassPlace> _places;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
  }) async =>
      _places;
}

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

class _CountingValhalla extends ValhallaService {
  _CountingValhalla({required this.onRoute});
  final VoidCallback onRoute;

  @override
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
  }) async {
    onRoute();
    return null;
  }
}

class _DelayedValhalla extends ValhallaService {
  _DelayedValhalla({
    required this.delay,
    required this.onStart,
    required this.onEnd,
  });

  final Duration delay;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
  }) async {
    onStart();
    await Future<void>.delayed(delay);
    onEnd();
    return null;
  }
}

class _ControllableOverpass extends OverpassService {
  _ControllableOverpass(this._completers);
  final List<Completer<List<OverpassPlace>>> _completers;
  int _callIndex = 0;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
  }) {
    if (_callIndex < _completers.length) {
      return _completers[_callIndex++].future;
    }
    return Future.value([]);
  }
}

class _CountingOverpass extends OverpassService {
  _CountingOverpass({required this.onQuery, required this.delay});
  final VoidCallback onQuery;
  final Duration delay;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
  }) async {
    onQuery();
    await Future<void>.delayed(delay);
    return [];
  }
}
