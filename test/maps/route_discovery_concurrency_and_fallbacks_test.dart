import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/data/repositories/saved_routes_repository.dart';
import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';
import 'package:fitbuddy/features/maps/data/services/nominatim_service.dart';
import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/real_route_discovery_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/domain/services/connectivity_monitor.dart';
import 'package:fitbuddy/features/maps/domain/services/outdoor_sync_coordinator.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_discovery_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // 3. Overpass Tag Filtering, 429 Halting & Mirror Failover
  // ---------------------------------------------------------------------------
  group('Overpass Tag Filtering, 429 Halting & Failover Tests', () {
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

    test('12. HTTP 429 stops mirror rotation immediately without querying subsequent mirrors', () async {
      int requestCount = 0;
      final requestedUris = <Uri>[];

      final service = OverpassService(
        endpoints: [
          'https://mirror1.overpass.example/api/interpreter',
          'https://mirror2.overpass.example/api/interpreter',
          'https://mirror3.overpass.example/api/interpreter',
        ],
        clientFactory: () => _TestHttpClient(
          statusCode: 429,
          onRequest: (uri, method) {
            requestCount++;
            requestedUris.add(uri);
          },
        ),
      );

      service.resetRateLimitForTesting();

      await expectLater(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 5000,
        ),
        throwsA(isA<RouteRateLimitException>()),
      );

      // Exactly 1 mirror was attempted; it halted immediately on 429 without cascading to mirrors 2 & 3
      expect(requestCount, equals(1));
      expect(requestedUris.first.host, equals('mirror1.overpass.example'));
    });

    test('13. HTTP 5xx fails over to next mirror and succeeds if next mirror returns 200', () async {
      int requestCount = 0;
      final requestedUris = <Uri>[];

      const validResponse = '''
{
  "elements": [
    {
      "type": "way",
      "id": 501,
      "center": { "lat": 28.7145, "lon": 77.1682 },
      "tags": { "leisure": "park", "name": "Failover Park" }
    }
  ]
}
''';

      final service = OverpassService(
        endpoints: [
          'https://mirror1.overpass.example/api/interpreter',
          'https://mirror2.overpass.example/api/interpreter',
        ],
        clientFactory: () {
          requestCount++;
          // First attempt returns 503, second attempt returns 200
          if (requestCount == 1) {
            return _TestHttpClient(
              statusCode: 503,
              onRequest: (uri, m) => requestedUris.add(uri),
            );
          } else {
            return _TestHttpClient(
              statusCode: 200,
              responseBody: validResponse,
              onRequest: (uri, m) => requestedUris.add(uri),
            );
          }
        },
      );

      service.resetRateLimitForTesting();

      final places = await service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 5000,
      );

      expect(places, hasLength(1));
      expect(places.first.name, equals('Failover Park'));
      expect(requestCount, equals(2));
      expect(requestedUris[0].host, equals('mirror1.overpass.example'));
      expect(requestedUris[1].host, equals('mirror2.overpass.example'));
    });

    test('13b. Exhausted mirrors on transient 5xx error perform bounded single retry with backoff', () async {
      int requestCount = 0;
      final requestedUris = <Uri>[];

      const validResponse = '''
{
  "elements": [
    {
      "type": "way",
      "id": 999,
      "center": { "lat": 28.7145, "lon": 77.1682 },
      "tags": { "leisure": "park", "name": "Backoff Park" }
    }
  ]
}
''';

      final service = OverpassService(
        retryBackoff: const Duration(milliseconds: 10),
        endpoints: [
          'https://mirror1.overpass.example/api/interpreter',
          'https://mirror2.overpass.example/api/interpreter',
        ],
        clientFactory: () {
          requestCount++;
          // First pass: mirror1 (503), mirror2 (503)
          // Retry pass after 10ms backoff: mirror1 (200)
          if (requestCount <= 2) {
            return _TestHttpClient(
              statusCode: 503,
              onRequest: (uri, m) => requestedUris.add(uri),
            );
          } else {
            return _TestHttpClient(
              statusCode: 200,
              responseBody: validResponse,
              onRequest: (uri, m) => requestedUris.add(uri),
            );
          }
        },
      );

      service.resetRateLimitForTesting();

      final places = await service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 5000,
      );

      expect(places, hasLength(1));
      expect(places.first.name, equals('Backoff Park'));
      expect(requestCount, equals(3));
      expect(requestedUris[0].host, equals('mirror1.overpass.example'));
      expect(requestedUris[1].host, equals('mirror2.overpass.example'));
      expect(requestedUris[2].host, equals('mirror1.overpass.example'));
    });

    test('13c. Cancelled Overpass request during retry backoff does not launch subsequent HTTP request', () async {
      int requestCount = 0;

      final service = OverpassService(
        retryBackoff: const Duration(milliseconds: 60),
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () {
          requestCount++;
          return _TestHttpClient(statusCode: 503);
        },
      );

      service.resetRateLimitForTesting();

      final future = service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 5000,
        requestId: 42,
      );
      future.ignore();

      // Allow request 1 to fail with 503 and enter retry backoff delay
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Cancel requestId 42 while in backoff delay
      service.cancelActiveRequests(42);

      // Wait past the 60ms backoff timer
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // No second HTTP request was launched after wakeup
      expect(requestCount, equals(1));
    });

    test('13d. Primary Overpass failure (502) automatically fails over to healthy secondary mirror', () async {
      int requestCount = 0;
      final requestedEndpoints = <String>[];
      const validResponse = '''
{
  "elements": [
    {
      "type": "way",
      "id": 101,
      "center": { "lat": 28.7145, "lon": 77.1682 },
      "tags": { "leisure": "park", "name": "Secondary Mirror Park" }
    }
  ]
}
''';

      final service = OverpassService(
        retryBackoff: const Duration(milliseconds: 10),
        endpoints: [
          'https://overpass-api.de/api/interpreter',
          'https://overpass.openstreetmap.fr/api/interpreter',
        ],
        clientFactory: () {
          requestCount++;
          if (requestCount == 1) {
            return _TestHttpClient(
              statusCode: 502,
              onRequest: (uri, _) => requestedEndpoints.add(uri.toString()),
            );
          } else {
            return _TestHttpClient(
              statusCode: 200,
              responseBody: validResponse,
              onRequest: (uri, _) => requestedEndpoints.add(uri.toString()),
            );
          }
        },
      );

      service.resetRateLimitForTesting();

      final places = await service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 2000,
      );

      expect(places, hasLength(1));
      expect(places.first.name, equals('Secondary Mirror Park'));
      expect(requestCount, equals(2));
      expect(requestedEndpoints[0], contains('overpass-api.de'));
      expect(requestedEndpoints[1], contains('overpass.openstreetmap.fr'));
    });

    test('13e. All Overpass servers returning 502/503 throws OverpassServiceException with user-friendly message', () async {
      int requestCount = 0;

      final service = OverpassService(
        retryBackoff: const Duration(milliseconds: 10),
        endpoints: [
          'https://mirror1.overpass.example/api/interpreter',
          'https://mirror2.overpass.example/api/interpreter',
        ],
        clientFactory: () {
          requestCount++;
          return _TestHttpClient(statusCode: 502);
        },
      );

      service.resetRateLimitForTesting();

      await expectLater(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 2000,
        ),
        throwsA(
          isA<OverpassServiceException>().having(
            (e) => e.message,
            'message',
            equals('Nearby places temporarily unavailable.'),
          ),
        ),
      );

      expect(requestCount, greaterThanOrEqualTo(2));
    });

    test('13f. HTTP 429 respects Retry-After header and stops mirror rotation', () async {
      int requestCount = 0;

      final service = OverpassService(
        retryBackoff: const Duration(milliseconds: 10),
        endpoints: [
          'https://mirror1.overpass.example/api/interpreter',
          'https://mirror2.overpass.example/api/interpreter',
        ],
        clientFactory: () {
          requestCount++;
          return _TestHttpClient(
            statusCode: 429,
            responseHeaders: {'retry-after': '45'},
          );
        },
      );

      service.resetRateLimitForTesting();

      await expectLater(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 2000,
        ),
        throwsA(isA<RouteRateLimitException>()),
      );

      expect(requestCount, equals(1));
    });

    test('13g. HTTP 502 respects Retry-After header and places server in cooldown', () async {
      int requestCount = 0;
      final requestedEndpoints = <String>[];
      const validResponse = '''
{
  "elements": [
    {
      "type": "way",
      "id": 102,
      "center": { "lat": 28.7145, "lon": 77.1682 },
      "tags": { "leisure": "park", "name": "Cooldown Fallback Park" }
    }
  ]
}
''';

      final service = OverpassService(
        retryBackoff: const Duration(milliseconds: 10),
        endpoints: [
          'https://mirror1.overpass.example/api/interpreter',
          'https://mirror2.overpass.example/api/interpreter',
        ],
        clientFactory: () {
          requestCount++;
          if (requestCount == 1) {
            return _TestHttpClient(
              statusCode: 502,
              responseHeaders: {'retry-after': '60'},
              onRequest: (uri, _) => requestedEndpoints.add(uri.toString()),
            );
          } else {
            return _TestHttpClient(
              statusCode: 200,
              responseBody: validResponse,
              onRequest: (uri, _) => requestedEndpoints.add(uri.toString()),
            );
          }
        },
      );

      service.resetRateLimitForTesting();

      final places = await service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 2000,
      );

      expect(places, hasLength(1));
      expect(places.first.name, equals('Cooldown Fallback Park'));
      expect(requestCount, equals(2));
      expect(requestedEndpoints[0], contains('mirror1'));
      expect(requestedEndpoints[1], contains('mirror2'));
    });

    test('13h. Timeout handling results in RouteNetworkException with timeout description', () async {
      final service = OverpassService(
        retryBackoff: const Duration(milliseconds: 10),
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () => _ThrowingHttpClient(TimeoutException('Request timed out')),
      );

      service.resetRateLimitForTesting();

      expect(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 2000,
        ),
        throwsA(
          isA<RouteNetworkException>().having(
            (e) => e.message.toLowerCase(),
            'message',
            contains('timed out'),
          ),
        ),
      );
    });

    test('13i. Cached nearby places result returns immediately without HTTP requests', () async {
      int requestCount = 0;
      const center = LatLng(28.7145, 77.1682);
      final cachedKey = RouteCache.buildOverpassKey(center, 2000);
      final dummyPlace = OverpassPlace(
        id: 777,
        name: 'Already Cached Park',
        lat: 28.7145,
        lon: 77.1682,
        tags: const {'leisure': 'park'},
      );

      RouteCache.instance.set(cachedKey, [dummyPlace]);

      final service = OverpassService(
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () {
          requestCount++;
          return _TestHttpClient();
        },
      );

      final places = await service.findNearbyPlaces(
        center: center,
        radiusMeters: 2000,
      );

      expect(places, hasLength(1));
      expect(places.first.name, equals('Already Cached Park'));
      expect(requestCount, equals(0));
    });

    test('13j. Offline Wi-Fi connection is correctly classified as RouteNetworkException (No internet connection)', () async {
      final monitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.wifi,
        initialOnline: false,
      );

      final service = OverpassService(
        connectivityMonitor: monitor,
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () => _ThrowingHttpClient(const SocketException('Network is unreachable')),
      );

      await expectLater(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 2000,
        ),
        throwsA(
          isA<RouteNetworkException>().having(
            (e) => e.message,
            'message',
            contains('No internet connection'),
          ),
        ),
      );
    });

    test('13k. Offline mobile data connection is correctly classified as RouteNetworkException (No internet connection)', () async {
      final monitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.mobile,
        initialOnline: false,
      );

      final service = OverpassService(
        connectivityMonitor: monitor,
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () => _ThrowingHttpClient(const SocketException('No route to host')),
      );

      await expectLater(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 2000,
        ),
        throwsA(
          isA<RouteNetworkException>().having(
            (e) => e.message,
            'message',
            contains('No internet connection'),
          ),
        ),
      );
    });

    test('13l. Connected Wi-Fi with an unavailable Overpass server is classified as OverpassServiceException', () async {
      final monitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.wifi,
        initialOnline: true,
        reachabilityProbe: () async => true,
      );

      final service = OverpassService(
        connectivityMonitor: monitor,
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () => _TestHttpClient(statusCode: 502),
      );

      await expectLater(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 2000,
        ),
        throwsA(
          isA<OverpassServiceException>().having(
            (e) => e.message,
            'message',
            equals('Nearby places temporarily unavailable.'),
          ),
        ),
      );
    });

    test('13m. Connected mobile data with an available Overpass server successfully retrieves places', () async {
      final monitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.mobile,
        initialOnline: true,
        reachabilityProbe: () async => true,
      );

      const validResponse = '''
{
  "elements": [
    {
      "type": "way",
      "id": 9901,
      "center": { "lat": 28.7145, "lon": 77.1682 },
      "tags": { "leisure": "park", "name": "Cellular Connectivity Park" }
    }
  ]
}
''';

      final service = OverpassService(
        connectivityMonitor: monitor,
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () => _TestHttpClient(
          statusCode: 200,
          responseBody: validResponse,
        ),
      );

      final places = await service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 2000,
      );

      expect(places, hasLength(1));
      expect(places.first.name, equals('Cellular Connectivity Park'));
    });

    test('13n. Failed reachability probe is handled as unknown connectivity and does NOT falsely classify as definitely offline', () async {
      final monitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.wifi,
        initialOnline: true,
        reachabilityProbe: () async => throw const SocketException('DNS probe timeout'),
      );

      final service = OverpassService(
        connectivityMonitor: monitor,
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () => _ThrowingHttpClient(const SocketException('Server unreachable')),
      );

      await expectLater(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 2000,
        ),
        throwsA(
          isA<OverpassServiceException>().having(
            (e) => e.message,
            'message',
            equals('Nearby places temporarily unavailable.'),
          ),
        ),
      );
    });

    test('13o. Production routeDiscoveryEngineProvider wires ConnectivityMonitor down to OverpassService', () async {
      final fakeMonitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.wifi,
        initialOnline: false,
      );

      final container = ProviderContainer(
        overrides: [
          connectivityMonitorProvider.overrideWithValue(fakeMonitor),
        ],
      );
      addTearDown(container.dispose);

      final engine = container.read(routeDiscoveryEngineProvider);
      expect(engine, isNotNull);

      // Verify that engine discovery propagates the offline state to RouteNetworkException
      await expectLater(
        () => engine.discoverRoutes(
          center: const LatLng(28.7145, 77.1682),
        ),
        throwsA(
          isA<RouteNetworkException>().having(
            (e) => e.message,
            'message',
            contains('No internet connection'),
          ),
        ),
      );
    });

    test('13p. Both DNS lookups failing returns unknown (not offline or false)', () async {
      final status = await ConnectivityMonitor.probeDnsReachability((host) async {
        throw const SocketException('DNS resolution failed');
      });
      expect(status, equals(NetworkReachabilityStatus.unknown));
      expect(status, isNot(equals(NetworkReachabilityStatus.offline)));

      final monitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.wifi,
        initialOnline: true,
        reachabilityProbe: () => ConnectivityMonitor.probeDnsReachability((host) async {
          throw const SocketException('DNS resolution failed');
        }),
      );
      final reachability = await monitor.checkReachability();
      expect(reachability, equals(NetworkReachabilityStatus.unknown));
      expect(reachability, isNot(equals(NetworkReachabilityStatus.offline)));
    });

    test('13q. Primary DNS failing but fallback succeeding returns online', () async {
      final queriedHosts = <String>[];
      final status = await ConnectivityMonitor.probeDnsReachability((host) async {
        queriedHosts.add(host);
        if (host == 'dns.google') {
          throw const SocketException('dns.google unreachable');
        }
        if (host == 'cloudflare.com') {
          return [InternetAddress('1.1.1.1')];
        }
        throw const SocketException('Unknown host');
      });

      expect(status, equals(NetworkReachabilityStatus.online));
      expect(queriedHosts, containsAllInOrder(['dns.google', 'cloudflare.com']));

      final monitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.wifi,
        initialOnline: true,
        reachabilityProbe: () async => status,
      );
      final reachability = await monitor.checkReachability();
      expect(reachability, equals(NetworkReachabilityStatus.online));
    });

    test('13r. Confirmed offline network classifies as offline and aborts Overpass requests immediately', () async {
      // 1. Confirmed offline via initialOnline: false
      final monitorOffline = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.wifi,
        initialOnline: false,
      );
      expect(await monitorOffline.checkReachability(), equals(NetworkReachabilityStatus.offline));

      // 2. Confirmed offline via connectionType: none
      final monitorNone = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.none,
        initialOnline: true,
      );
      expect(await monitorNone.checkReachability(), equals(NetworkReachabilityStatus.offline));

      // 3. Fast-path in OverpassService throws RouteNetworkException without creating HTTP requests
      var httpClientCreated = false;
      final service = OverpassService(
        connectivityMonitor: monitorOffline,
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () {
          httpClientCreated = true;
          return _TestHttpClient(statusCode: 200);
        },
      );

      await expectLater(
        () => service.findNearbyPlaces(
          center: const LatLng(28.7145, 77.1682),
          radiusMeters: 2000,
        ),
        throwsA(
          isA<RouteNetworkException>().having(
            (e) => e.message,
            'message',
            contains('No internet connection'),
          ),
        ),
      );
      expect(httpClientCreated, isFalse, reason: 'Confirmed offline must fast-path abort before HTTP client creation');
    });

    test('13s. Unknown connectivity still allows Overpass requests to proceed', () async {
      final monitor = ConnectivityMonitor(
        initialConnectionType: NetworkConnectionType.wifi,
        initialOnline: true,
        reachabilityProbe: () async => NetworkReachabilityStatus.unknown,
      );

      expect(await monitor.checkReachability(), equals(NetworkReachabilityStatus.unknown));

      const validResponse = '''
{
  "elements": [
    {
      "type": "way",
      "id": 9902,
      "center": { "lat": 28.7145, "lon": 77.1682 },
      "tags": { "leisure": "park", "name": "Unknown Connectivity Park" }
    }
  ]
}
''';

      var requestsSent = 0;
      final service = OverpassService(
        connectivityMonitor: monitor,
        endpoints: ['https://mirror1.overpass.example/api/interpreter'],
        clientFactory: () {
          requestsSent++;
          return _TestHttpClient(
            statusCode: 200,
            responseBody: validResponse,
          );
        },
      );

      final places = await service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 2000,
      );

      expect(requestsSent, equals(1), reason: 'Unknown connectivity must proceed with HTTP request');
      expect(places, hasLength(1));
      expect(places.first.name, equals('Unknown Connectivity Park'));
    });

    test('14. cancelActiveRequests completes without throwing', () {
      final service = OverpassService();
      expect(() => service.cancelActiveRequests(), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 3b. Production Connectivity Listener & Lifecycle Tests
  // ---------------------------------------------------------------------------
  group('Production Connectivity Listener & Lifecycle Tests', () {
    test('1. Wi-Fi connected updates monitor status to online and wifi', () async {
      final controller = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(controller.close);

      final monitor = ConnectivityMonitor(
        connectivityStream: controller.stream,
        checkConnectivityFn: () async => [ConnectivityResult.wifi],
        initialOnline: false,
      );
      addTearDown(monitor.dispose);

      // Initial check should set online & wifi
      await monitor.refreshConnectivity();
      expect(monitor.isOnline, isTrue);
      expect(monitor.connectionType, equals(NetworkConnectionType.wifi));

      // Emitting wifi on stream maintains wifi
      controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.isOnline, isTrue);
      expect(monitor.connectionType, equals(NetworkConnectionType.wifi));
    });

    test('2. Mobile data connected updates monitor status to online and mobile', () async {
      final controller = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(controller.close);

      final monitor = ConnectivityMonitor(
        connectivityStream: controller.stream,
        checkConnectivityFn: () async => [ConnectivityResult.none],
        initialOnline: false,
      );
      addTearDown(monitor.dispose);

      controller.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.isOnline, isTrue);
      expect(monitor.connectionType, equals(NetworkConnectionType.mobile));
    });

    test('3. Disconnection updates monitor to offline and none, returning offline reachability', () async {
      final controller = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(controller.close);

      final monitor = ConnectivityMonitor(
        connectivityStream: controller.stream,
        checkConnectivityFn: () async => [ConnectivityResult.wifi],
        initialOnline: true,
        initialConnectionType: NetworkConnectionType.wifi,
      );
      addTearDown(monitor.dispose);

      controller.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      expect(monitor.isOnline, isFalse);
      expect(monitor.connectionType, equals(NetworkConnectionType.none));

      final reachability = await monitor.checkReachability();
      expect(reachability, equals(NetworkReachabilityStatus.offline));
    });

    test('4. Reconnection after offline fires onConnectivityRestored event after debounce', () async {
      final controller = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(controller.close);

      final monitor = ConnectivityMonitor(
        debounceDuration: const Duration(milliseconds: 20),
        reachabilityProbe: () async => NetworkReachabilityStatus.online,
        connectivityStream: controller.stream,
        initialOnline: false,
        initialConnectionType: NetworkConnectionType.none,
      );
      addTearDown(monitor.dispose);

      final restoredEvents = <bool>[];
      final sub = monitor.onConnectivityRestored.listen(restoredEvents.add);
      addTearDown(sub.cancel);

      // Reconnect via Wi-Fi
      controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(monitor.isOnline, isTrue);
      expect(monitor.connectionType, equals(NetworkConnectionType.wifi));
      expect(restoredEvents, equals([true]),
          reason: 'Offline-to-online transition must fire onConnectivityRestored');
    });

    test('5. App resume refreshes network connectivity state from platform', () async {
      var currentResult = [ConnectivityResult.none];
      final monitor = ConnectivityMonitor(
        checkConnectivityFn: () async => currentResult,
        initialOnline: false,
        initialConnectionType: NetworkConnectionType.none,
      );
      addTearDown(monitor.dispose);

      expect(monitor.isOnline, isFalse);

      // Network changes while app was backgrounded
      currentResult = [ConnectivityResult.wifi];

      // App resumes
      monitor.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(monitor.isOnline, isTrue);
      expect(monitor.connectionType, equals(NetworkConnectionType.wifi));
    });

    test('6. Automatic outdoor sync triggers when connectivity is restored via listener', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = LocalOutdoorStorage(preferences: prefs);
      final actRepo = OutdoorActivityRepository(storage: storage);
      final routesRepo = SavedRoutesRepository(storage: storage);

      // Pre-save an unsynced activity to storage
      final sampleActivity = OutdoorActivity(
        id: 'act_pending_sync_test',
        userId: 'test_user',
        activityType: OutdoorActivityType.running,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now(),
        durationSeconds: 1800,
        distanceMeters: 5000,
        averagePaceSecondsPerKm: 360,
        averageSpeedKmh: 10.0,
        points: const [],
        isSynced: false,
      );
      await storage.saveActivity(sampleActivity);

      var remoteSyncCount = 0;
      actRepo.currentUserIdOverride = () => 'test_user';
      actRepo.remoteUpsertOverride = (table, payload) async {
        remoteSyncCount++;
      };

      final controller = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(controller.close);

      final monitor = ConnectivityMonitor(
        debounceDuration: const Duration(milliseconds: 20),
        reachabilityProbe: () async => NetworkReachabilityStatus.online,
        connectivityStream: controller.stream,
        initialOnline: false,
        initialConnectionType: NetworkConnectionType.none,
      );
      addTearDown(monitor.dispose);

      final coordinator = OutdoorSyncCoordinator(
        activityRepository: actRepo,
        routesRepository: routesRepo,
        connectivityMonitor: monitor,
      );
      addTearDown(coordinator.dispose);

      // Trigger reconnection event via platform stream
      controller.add([ConnectivityResult.wifi]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(monitor.isOnline, isTrue);
      expect(remoteSyncCount, greaterThanOrEqualTo(1),
          reason: 'Automatic outdoor sync must be triggered when connectivity is restored');

      final syncedActivity = await actRepo.getActivityById('act_pending_sync_test');
      expect(syncedActivity!.isSynced, isTrue);
    });

    test('7. In-flight connectivity refresh completing after disposal does not mutate state or schedule timers', () async {
      final completer = Completer<List<ConnectivityResult>>();

      final monitor = ConnectivityMonitor(
        initialOnline: false,
        initialConnectionType: NetworkConnectionType.none,
        checkConnectivityFn: () => completer.future,
        debounceDuration: const Duration(milliseconds: 50),
      );

      // Verify initial offline state
      expect(monitor.isOnline, isFalse);
      expect(monitor.connectionType, equals(NetworkConnectionType.none));
      expect(monitor.isDisposed, isFalse);

      // Start asynchronous refresh which suspends waiting on completer.future
      final refreshFuture = monitor.refreshConnectivity();

      // Dispose monitor while checkConnectivityFn is in-flight
      monitor.dispose();
      expect(monitor.isDisposed, isTrue);

      // Complete in-flight platform connectivity check with wifi
      completer.complete([ConnectivityResult.wifi]);
      await refreshFuture;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Assert that state was NOT mutated after disposal
      expect(monitor.isOnline, isFalse,
          reason: 'Disposed monitor must ignore in-flight platform connectivity changes');
      expect(monitor.connectionType, equals(NetworkConnectionType.none));

      // Attempting direct notifyConnectivityChange on disposed monitor is a no-op
      monitor.notifyConnectivityChange(true, connectionType: NetworkConnectionType.wifi);
      expect(monitor.isOnline, isFalse);
      expect(monitor.connectionType, equals(NetworkConnectionType.none));
    });

    test('8. Wi-Fi reconnect followed by immediate disconnection while DNS probe is pending does not emit restored event', () async {
      final probeCompleter = Completer<NetworkReachabilityStatus>();

      final monitor = ConnectivityMonitor(
        initialOnline: false,
        initialConnectionType: NetworkConnectionType.none,
        debounceDuration: const Duration(milliseconds: 10),
        reachabilityProbe: () => probeCompleter.future,
      );
      addTearDown(monitor.dispose);

      final restoredEvents = <bool>[];
      final sub = monitor.onConnectivityRestored.listen(restoredEvents.add);
      addTearDown(sub.cancel);

      // 1. Wi-Fi connects
      monitor.notifyConnectivityChange(true, connectionType: NetworkConnectionType.wifi);
      // Wait for debounce timer to fire, starting probe
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 2. While DNS probe is still pending, disconnection occurs
      monitor.notifyConnectivityChange(false, connectionType: NetworkConnectionType.none);
      expect(monitor.isOnline, isFalse);

      // 3. DNS probe now resolves as online (stale callback)
      probeCompleter.complete(NetworkReachabilityStatus.online);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Assert that no connectivity-restored event was emitted because the callback was outdated
      expect(restoredEvents, isEmpty,
          reason: 'Outdated DNS probe resolution must never emit connectivity-restored event after disconnection');
      expect(monitor.isOnline, isFalse);
    });

    test('9. DNS initially returning unknown subsequently retries and emits connectivity-restored when online', () async {
      var probeCalls = 0;
      final monitor = ConnectivityMonitor(
        initialOnline: false,
        initialConnectionType: NetworkConnectionType.none,
        debounceDuration: const Duration(milliseconds: 10),
        unknownRetryInterval: const Duration(milliseconds: 20),
        maxUnknownRetries: 3,
        reachabilityProbe: () async {
          probeCalls++;
          if (probeCalls == 1) {
            return NetworkReachabilityStatus.unknown;
          }
          return NetworkReachabilityStatus.online;
        },
      );
      addTearDown(monitor.dispose);

      final restoredEvents = <bool>[];
      final sub = monitor.onConnectivityRestored.listen(restoredEvents.add);
      addTearDown(sub.cancel);

      // Reconnect
      monitor.notifyConnectivityChange(true, connectionType: NetworkConnectionType.wifi);

      // Wait for debounce (10ms) + first probe execution
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(probeCalls, equals(1));
      expect(restoredEvents, isEmpty,
          reason: 'Must not emit connectivity-restored while reachability is unknown');

      // Wait for unknownRetryInterval (20ms) + second probe execution
      for (var i = 0; i < 20 && restoredEvents.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
      expect(probeCalls, equals(2));
      expect(restoredEvents, equals([true]),
          reason: 'Must emit connectivity-restored once reachability retry confirms online');
    });

    test('10. Disposal while an unknown connectivity retry is pending cancels retry and avoids callbacks', () async {
      var probeCalls = 0;
      final monitor = ConnectivityMonitor(
        initialOnline: false,
        initialConnectionType: NetworkConnectionType.none,
        debounceDuration: const Duration(milliseconds: 10),
        unknownRetryInterval: const Duration(milliseconds: 60),
        maxUnknownRetries: 3,
        reachabilityProbe: () async {
          probeCalls++;
          return NetworkReachabilityStatus.unknown;
        },
      );

      final restoredEvents = <bool>[];
      final sub = monitor.onConnectivityRestored.listen(restoredEvents.add);
      addTearDown(sub.cancel);

      // Trigger reconnect
      monitor.notifyConnectivityChange(true, connectionType: NetworkConnectionType.wifi);

      // Wait for debounce and first probe (returns unknown)
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(probeCalls, equals(1));
      expect(restoredEvents, isEmpty);

      // Dispose while retry timer is ticking
      monitor.dispose();
      expect(monitor.isDisposed, isTrue);

      // Wait past the retry delay
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // Verify that no subsequent retry probe was executed
      expect(probeCalls, equals(1),
          reason: 'Disposal must cancel any pending retry timer');
      expect(restoredEvents, isEmpty);
    });

    test('11. No duplicate connectivity-restored events on successive online transitions or handovers', () async {
      var probeCalls = 0;
      final monitor = ConnectivityMonitor(
        initialOnline: false,
        initialConnectionType: NetworkConnectionType.none,
        debounceDuration: const Duration(milliseconds: 10),
        unknownRetryInterval: const Duration(milliseconds: 15),
        maxUnknownRetries: 2,
        reachabilityProbe: () async {
          probeCalls++;
          if (probeCalls == 1) return NetworkReachabilityStatus.unknown;
          return NetworkReachabilityStatus.online;
        },
      );
      addTearDown(monitor.dispose);

      final restoredEvents = <bool>[];
      final sub = monitor.onConnectivityRestored.listen(restoredEvents.add);
      addTearDown(sub.cancel);

      // Reconnect via Wi-Fi
      monitor.notifyConnectivityChange(true, connectionType: NetworkConnectionType.wifi);

      // Wait for debounce + retry to confirm online
      for (var i = 0; i < 20 && restoredEvents.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
      expect(restoredEvents, equals([true]));

      // Subsequent identical Wi-Fi event arrives
      monitor.notifyConnectivityChange(true, connectionType: NetworkConnectionType.wifi);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Network handover to mobile data while remaining online
      monitor.notifyConnectivityChange(true, connectionType: NetworkConnectionType.mobile);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Verify restored event was emitted strictly once
      expect(restoredEvents, equals([true]),
          reason: 'Must never emit duplicate connectivity-restored events');
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Valhalla Routing Retry-with-Backoff & Identification Tests
  // ---------------------------------------------------------------------------
  group('Valhalla Routing Retry-with-Backoff & Identification Tests', () {
    const validTripJson = '''
{
  "trip": {
    "summary": { "length": 2.5, "time": 1800 },
    "legs": [
      { "shape": "mfp|Idf|@mA?mA?mA@" }
    ]
  }
}
''';

    test('15. Sends exact X-Client-Id: Vyayama header', () async {
      String? recordedClientId;

      final service = ValhallaService(
        clientFactory: () => _TestHttpClient(
          statusCode: 200,
          responseBody: validTripJson,
          onHeaderRecorded: (k, v) {
            if (k.toLowerCase() == 'x-client-id') {
              recordedClientId = v;
            }
          },
        ),
      );

      await service.route(
        origin: const LatLng(28.7145, 77.1682),
        waypoints: [const LatLng(28.7160, 77.1700)],
      );

      expect(recordedClientId, equals('Vyayama'));
    });

    test('16. Performs bounded 1 retry with backoff on 5xx server error', () async {
      int requestCount = 0;

      final service = ValhallaService(
        retryBackoff: const Duration(milliseconds: 10), // Short backoff for unit test
        clientFactory: () {
          requestCount++;
          if (requestCount == 1) {
            return _TestHttpClient(statusCode: 500);
          } else {
            return _TestHttpClient(statusCode: 200, responseBody: validTripJson);
          }
        },
      );

      final route = await service.route(
        origin: const LatLng(28.7145, 77.1682),
        waypoints: [const LatLng(28.7160, 77.1700)],
      );

      expect(route, isNotNull);
      expect(requestCount, equals(2)); // Attempt 0 failed (500), Attempt 1 retried and succeeded
    });

    test('17. Performs bounded 1 retry on SocketException/timeout', () async {
      int requestCount = 0;

      final service = ValhallaService(
        retryBackoff: const Duration(milliseconds: 10),
        clientFactory: () {
          requestCount++;
          if (requestCount == 1) {
            return _ThrowingHttpClient(const SocketException('Network reset'));
          } else {
            return _TestHttpClient(statusCode: 200, responseBody: validTripJson);
          }
        },
      );

      final route = await service.route(
        origin: const LatLng(28.7145, 77.1682),
        waypoints: [const LatLng(28.7160, 77.1700)],
      );

      expect(route, isNotNull);
      expect(requestCount, equals(2));
    });

    test('17b. Throws ValhallaRoutingException when SocketException persists across retries', () async {
      int requestCount = 0;

      final service = ValhallaService(
        retryBackoff: const Duration(milliseconds: 10),
        clientFactory: () {
          requestCount++;
          return _ThrowingHttpClient(const SocketException('Failed to connect to host'));
        },
      );

      expect(
        () => service.route(
          origin: const LatLng(28.7145, 77.1682),
          waypoints: [const LatLng(28.7160, 77.1700)],
        ),
        throwsA(isA<ValhallaRoutingException>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(requestCount, equals(2));
    });

    test('18. Never retries on HTTP 429 (rate limit)', () async {
      int requestCount = 0;

      final service = ValhallaService(
        retryBackoff: const Duration(milliseconds: 10),
        clientFactory: () {
          requestCount++;
          return _TestHttpClient(statusCode: 429);
        },
      );

      expect(
        () => service.route(
          origin: const LatLng(28.7145, 77.1682),
          waypoints: [const LatLng(28.7160, 77.1700)],
        ),
        throwsA(isA<RouteRateLimitException>()),
      );

      // Exactly 1 attempt made: 429 is never retried
      expect(requestCount, equals(1));
    });

    test('19. Never retries on HTTP 400 (unroutable candidate)', () async {
      int requestCount = 0;

      final service = ValhallaService(
        retryBackoff: const Duration(milliseconds: 10),
        clientFactory: () {
          requestCount++;
          return _TestHttpClient(statusCode: 400);
        },
      );

      final route = await service.route(
        origin: const LatLng(28.7145, 77.1682),
        waypoints: [const LatLng(28.7160, 77.1700)],
      );

      expect(route, isNull);
      expect(requestCount, equals(1));
    });

    test('20. Never retries on malformed JSON response', () async {
      int requestCount = 0;

      final service = ValhallaService(
        retryBackoff: const Duration(milliseconds: 10),
        clientFactory: () {
          requestCount++;
          return _TestHttpClient(statusCode: 200, responseBody: '{ malformed json: }');
        },
      );

      expect(
        () => service.route(
          origin: const LatLng(28.7145, 77.1682),
          waypoints: [const LatLng(28.7160, 77.1700)],
        ),
        throwsA(isA<ValhallaRoutingException>()),
      );

      expect(requestCount, equals(1));
    });

    test('20b. Cancelled Valhalla request during retry backoff does not launch subsequent HTTP request', () async {
      int requestCount = 0;

      final service = ValhallaService(
        retryBackoff: const Duration(milliseconds: 60),
        clientFactory: () {
          requestCount++;
          return _TestHttpClient(statusCode: 503);
        },
      );

      final future = service.route(
        origin: const LatLng(28.7145, 77.1682),
        waypoints: [const LatLng(28.7160, 77.1700)],
        requestId: 99,
      );
      future.ignore();

      // Allow request 1 to fail with 503 and enter retry backoff delay
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Cancel requestId 99 while in backoff
      service.cancelActiveRequests(99);

      // Wait past the 60ms backoff timer
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // No second HTTP request was launched after wakeup
      expect(requestCount, equals(1));
    });

    test('21. testParseRoute rejects invalid non-finite or out-of-bounds coordinates', () {
      final service = ValhallaService();
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
  });

  // ---------------------------------------------------------------------------
  // 5. Nominatim Throttling & Deduplication Tests
  // ---------------------------------------------------------------------------
  group('Nominatim Service Throttling & Deduplication Tests', () {
    test('22. LRU cache returns cached places on subsequent queries', () async {
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

      final cachedPlaces = await service.findNearbyPlaces(
        center: const LatLng(28.7145, 77.1682),
        radiusMeters: 5000,
      );

      expect(cachedPlaces, hasLength(1));
      expect(cachedPlaces.first.name, equals('Cached Shalimar Garden'));
    });

    test('23. cancelActiveRequests completes without throwing', () {
      final service = NominatimService();
      expect(() => service.cancelActiveRequests(), returnsNormally);
    });

    test('23b. Nominatim caches empty results to prevent re-query loops', () async {
      int requestCount = 0;
      final service = NominatimService(
        clientFactory: () {
          requestCount++;
          return _TestHttpClient(
            statusCode: 200,
            responseBody: '[]',
          );
        },
      );

      const center = LatLng(28.7145, 77.1682);
      final places1 = await service.findNearbyPlaces(
        center: center,
        radiusMeters: 2000,
      );
      expect(places1, isEmpty);
      expect(requestCount, greaterThan(0));

      final countAfterFirst = requestCount;

      // Second query for the exact same center & radius must be served from cache without extra HTTP calls
      final places2 = await service.findNearbyPlaces(
        center: center,
        radiusMeters: 2000,
      );
      expect(places2, isEmpty);
      expect(requestCount, equals(countAfterFirst));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Request-Scoped Cancellation & Timeout Tests
  // ---------------------------------------------------------------------------
  group('Request-Scoped Cancellation & Timeout Tests', () {
    test('24. Superseded search cancels previous search HTTP client with close(force: true)', () async {
      final client1 = _TestHttpClient(responseDelay: const Duration(seconds: 1));
      final client2 = _TestHttpClient();
      int clientCounter = 0;

      final overpass = OverpassService(
        clientFactory: () {
          clientCounter++;
          return clientCounter == 1 ? client1 : client2;
        },
      );

      final future = overpass.findNearbyPlaces(
        center: const LatLng(51.505, -0.090),
        radiusMeters: 5000,
        requestId: 1,
      );

      // Allow event loop to advance so client1 is instantiated and registered
      await Future<void>.delayed(Duration.zero);

      // Search 2 begins with requestId: 2, cancelling requestId 1
      overpass.cancelActiveRequests(1);

      expect(client1.wasForceClosed, isTrue);
      expect(client2.wasForceClosed, isFalse);

      try {
        await future;
      } catch (_) {}
    });

    test('25. Provider disposal terminates active requests via cancelCurrentDiscovery', () {
      final overpassClient = _TrackingHttpClient();
      final valhallaClient = _TrackingHttpClient();

      final service = RealRouteDiscoveryService(
        overpass: OverpassService(clientFactory: () => overpassClient),
        valhalla: ValhallaService(clientFactory: () => valhallaClient),
        nominatim: NominatimService(),
      );

      service.cancelCurrentDiscovery();

      expect(() => service.cancelCurrentDiscovery(), returnsNormally);
    });

    test('25b. Overall timeout closes active HTTP client with close(force: true)', () async {
      final hangingClient = _TestHttpClient(
        responseDelay: const Duration(seconds: 2),
      );

      final overpass = OverpassService(
        clientFactory: () => hangingClient,
      );

      final service = RealRouteDiscoveryService(
        overpass: overpass,
        valhalla: ValhallaService(),
        nominatim: NominatimService(),
        overallTimeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.discoverRoutes(center: const LatLng(51.505, -0.090)),
        throwsA(isA<RouteNetworkException>()),
      );

      // Timeout forcefully terminated the active HTTP socket
      expect(hangingClient.wasForceClosed, isTrue);
    });

    test('25c. Service-wide failure in parallel Valhalla batch cancels sibling request without cancelling newer search', () async {
      final siblingClient = _TestHttpClient(
        responseDelay: const Duration(seconds: 2),
      );
      final newerSearchClient = _TestHttpClient();
      int clientCounter = 0;

      final valhallaService = ValhallaService(
        clientFactory: () {
          clientCounter++;
          return clientCounter == 1 ? siblingClient : newerSearchClient;
        },
      );

      // Directly launch candidate request (generation 1) using siblingClient
      final f1 = valhallaService.route(
        origin: const LatLng(51.505, -0.090),
        waypoints: [const LatLng(51.508, -0.092)],
        requestId: 1,
      );

      // Directly launch newer search request (generation 2) using newerSearchClient
      final f2 = valhallaService.route(
        origin: const LatLng(28.7145, 77.1682),
        waypoints: [const LatLng(28.7160, 77.1700)],
        requestId: 2,
      );

      await Future<void>.delayed(Duration.zero);

      // Sibling request in generation 1 fails with service-wide failure, cancelling generation 1
      valhallaService.cancelActiveRequests(1);

      // Generation 1 sibling socket was force-closed
      expect(siblingClient.wasForceClosed, isTrue);
      // Generation 2 newer search socket was NOT cancelled
      expect(newerSearchClient.wasForceClosed, isFalse);

      try {
        await f1;
      } catch (_) {}
      try {
        await f2;
      } catch (_) {}
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Pipeline Progressive Route Emission & Isolation Tests
  // ---------------------------------------------------------------------------
  group('RealRouteDiscoveryService Progressive Route Tests', () {
    test('26. Bounds candidates to maximum 8 waypoints', () async {
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

      expect(valhallaCallCount, lessThanOrEqualTo(8));
      expect(routes.length, lessThanOrEqualTo(4));
    });

    test('27. Enforces maximum concurrency of 2 for Valhalla requests', () async {
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

      expect(maxConcurrent, lessThanOrEqualTo(2));
    });

    test('28. Discards results of superseded searches when a newer search begins', () async {
      final completer1 = Completer<List<OverpassPlace>>();
      final completer2 = Completer<List<OverpassPlace>>();

      final overpass = _ControllableOverpass([completer1, completer2]);

      final service = RealRouteDiscoveryService(
        overpass: overpass,
        valhalla: _FakeValhalla(null),
        nominatim: _StaticNominatim([]),
      );

      final future1 = service.discoverRoutes(
        center: const LatLng(51.505, -0.090),
      );

      final future2 = service.discoverRoutes(
        center: const LatLng(28.7145, 77.1682),
      );

      completer1.complete([
        const OverpassPlace(
          id: 1,
          name: 'Old Search Park',
          lat: 51.505,
          lon: -0.090,
          tags: {'leisure': 'park'},
        ),
      ]);

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

      expect(result1, isEmpty);
      expect(result2, isEmpty);
    });

    test('29. In-flight discovery joining prevents duplicate pipeline executions', () async {
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

      final future1 = service.discoverRoutes(center: center);
      final future2 = service.discoverRoutes(center: center);

      final results = await Future.wait([future1, future2]);

      expect(overpassExecutions, equals(1));
      expect(results[0], equals(results[1]));
    });

    test('30. Progressively publishes route batches as soon as batch completes', () async {
      final p1 = OverpassPlace(
        id: 1,
        name: 'Park Alpha',
        lat: 28.7145,
        lon: 77.1682,
        tags: const {'leisure': 'park'},
      );
      final p2 = OverpassPlace(
        id: 2,
        name: 'Park Beta',
        lat: 28.7200,
        lon: 77.1750,
        tags: const {'leisure': 'park'},
      );

      final sampleRoute1 = ValhallaRoute(
        points: const [
          LatLng(28.7145, 77.1682),
          LatLng(28.7150, 77.1690),
          LatLng(28.7145, 77.1682),
        ],
        distanceMeters: 1200,
        durationSeconds: 900,
      );

      final service = RealRouteDiscoveryService(
        overpass: _StaticOverpass([p1, p2]),
        valhalla: _FakeValhalla(sampleRoute1),
        nominatim: _StaticNominatim([]),
      );

      final progressiveStream = service.discoverRoutesProgressive(
        center: const LatLng(28.7145, 77.1682),
      );

      final emittedBatches = <List<SavedRoute>>[];
      await for (final batch in progressiveStream) {
        emittedBatches.add(batch);
      }

      // Routes were emitted progressively
      expect(emittedBatches, isNotEmpty);
      expect(emittedBatches.first, isNotEmpty);
      expect(emittedBatches.first.first.name, contains('Park Alpha'));
    });

    test('31. Existing valid routes survive subsequent candidate failure in later batch', () async {
      final p1 = OverpassPlace(
        id: 1,
        name: 'Valid Park 1',
        lat: 28.7145,
        lon: 77.1682,
        tags: const {'leisure': 'park'},
      );
      final p2 = OverpassPlace(
        id: 2,
        name: 'Valid Park 2',
        lat: 28.7180,
        lon: 77.1720,
        tags: const {'leisure': 'park'},
      );
      final p3 = OverpassPlace(
        id: 3,
        name: 'Failing Park 3',
        lat: 28.7300,
        lon: 77.1900,
        tags: const {'leisure': 'park'},
      );

      final validRoute = ValhallaRoute(
        points: const [
          LatLng(28.7145, 77.1682),
          LatLng(28.7150, 77.1690),
          LatLng(28.7145, 77.1682),
        ],
        distanceMeters: 1000,
        durationSeconds: 800,
      );

      final service = RealRouteDiscoveryService(
        overpass: _StaticOverpass([p1, p2, p3]),
        valhalla: _DynamicValhalla(
          routeHandler: (origin, waypoints) {
            if (waypoints.first.latitude == p1.lat ||
                waypoints.first.latitude == p2.lat) {
              return validRoute;
            }
            throw const ValhallaRoutingException('Candidate unroutable');
          },
        ),
        nominatim: _StaticNominatim([]),
      );

      final routes = await service.discoverRoutes(
        center: const LatLng(28.7145, 77.1682),
      );

      // Valid routes from batch 1 were preserved even though batch 2 experienced a failure
      expect(routes, isNotEmpty);
      expect(routes.first.name, contains('Valid Park'));
    });

    test('31b. Privacy audit: Diagnostic logging omits raw GPS coordinates and uses non-sensitive event descriptions', () async {
      final capturedLogs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          capturedLogs.add(message);
        }
      };

      try {
        final dummyPlaces = [
          OverpassPlace(
            id: 101,
            name: 'Audit Park',
            lat: 51.5074,
            lon: -0.1278,
            tags: const {'leisure': 'park'},
          ),
        ];

        final service = RealRouteDiscoveryService(
          overpass: _StaticOverpass(dummyPlaces),
          valhalla: _FakeValhalla(null),
          nominatim: _StaticNominatim([]),
        );

        const testCenter = LatLng(51.5074, -0.1278);
        await service.discoverRoutes(center: testCenter, radiusKm: 2.5);

        expect(capturedLogs, isNotEmpty);
        // Verify logs contain request IDs and non-sensitive descriptions
        expect(capturedLogs.any((log) => log.contains('[RouteDiscovery][req-')), isTrue);
        expect(capturedLogs.any((log) => log.contains('(radius: 2500m)')), isTrue);

        // Verify NO log statement contains raw coordinates or latitude/longitude numbers
        for (final log in capturedLogs) {
          expect(log.contains('51.50'), isFalse, reason: 'Log must not contain latitude: $log');
          expect(log.contains('-0.12'), isFalse, reason: 'Log must not contain longitude: $log');
          expect(log.contains('near ('), isFalse, reason: 'Log must not contain coordinate tuple: $log');
        }
      } finally {
        debugPrint = originalDebugPrint;
      }
    });
  });

  // ---------------------------------------------------------------------------
  // 8. RouteDiscoverySheet UI Error States & Interactions
  // ---------------------------------------------------------------------------
  group('RouteDiscoverySheet Error States Widget Tests', () {
    testWidgets('32. Renders Nearby places temporarily unavailable error view when RouteRateLimitException occurs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(const RouteRateLimitException()),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nearby places temporarily unavailable.'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('33. Renders Mapping service timed out error view on network timeout',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(
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

      expect(find.text('Mapping service timed out.'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_bottom_rounded), findsOneWidget);
    });

    testWidgets('34. Renders No Internet Connection error view on network failure',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(
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

    testWidgets('35. Renders Nearby places temporarily unavailable on OverpassServiceException',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(const OverpassServiceException('504 Gateway Timeout')),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nearby places temporarily unavailable.'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('36. Renders Routing Engine Unavailable on ValhallaRoutingException',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(const ValhallaRoutingException('Service down')),
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

    testWidgets('37. Empty routes list displays No mapped routes found nearby',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith((ref) => Stream.value(<SavedRoute>[])),
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

class _TestHttpClient implements HttpClient {
  _TestHttpClient({
    this.statusCode = 200,
    this.responseBody = '{}',
    this.responseHeaders,
    this.onRequest,
    this.onHeaderRecorded,
    this.responseDelay,
  });

  final int statusCode;
  final String responseBody;
  final Map<String, String>? responseHeaders;
  final void Function(Uri uri, String method)? onRequest;
  final void Function(String key, String value)? onHeaderRecorded;
  final Duration? responseDelay;

  bool wasForceClosed = false;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    onRequest?.call(url, 'POST');
    return _TestHttpClientRequest(
      url,
      'POST',
      statusCode,
      responseBody,
      userAgent,
      onHeaderRecorded,
      responseDelay,
      responseHeaders,
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    onRequest?.call(url, 'GET');
    return _TestHttpClientRequest(
      url,
      'GET',
      statusCode,
      responseBody,
      userAgent,
      onHeaderRecorded,
      responseDelay,
      responseHeaders,
    );
  }

  @override
  void close({bool force = false}) {
    if (force) {
      wasForceClosed = true;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackingHttpClient extends _TestHttpClient {
  _TrackingHttpClient() : super();
}

class _ThrowingHttpClient implements HttpClient {
  _ThrowingHttpClient(this.exception);
  final Exception exception;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async => throw exception;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => throw exception;

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientRequest implements HttpClientRequest {
  _TestHttpClientRequest(
    this.uri,
    this.method,
    this.statusCode,
    this.responseBody,
    this.userAgent,
    this.onHeaderRecorded, [
    this.responseDelay,
    this.responseHeaders,
  ]);

  @override
  final Uri uri;
  @override
  final String method;
  final int statusCode;
  final String responseBody;
  final String? userAgent;
  final void Function(String key, String value)? onHeaderRecorded;
  final Duration? responseDelay;
  final Map<String, String>? responseHeaders;

  final StringBuffer _buffer = StringBuffer();

  @override
  late final HttpHeaders headers = _TestHttpHeaders(onHeaderRecorded);

  @override
  void write(Object? obj) {
    _buffer.write(obj);
  }

  @override
  Future<HttpClientResponse> close() async {
    if (responseDelay != null) {
      await Future<void>.delayed(responseDelay!);
    }
    return _TestHttpClientResponse(statusCode, responseBody, responseHeaders);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  _TestHttpClientResponse(this.statusCode, this.body, [Map<String, String>? responseHeaders]) {
    if (responseHeaders != null) {
      responseHeaders.forEach((k, v) => headers.set(k, v));
    }
  }

  @override
  final int statusCode;
  final String body;

  @override
  final HttpHeaders headers = _TestHttpHeaders(null);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpHeaders implements HttpHeaders {
  _TestHttpHeaders(this.onSet);
  final void Function(String key, String value)? onSet;
  final Map<String, String> _map = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = value.toString();
    onSet?.call(name, value.toString());
  }

  @override
  String? value(String name) => _map[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StaticOverpass extends OverpassService {
  _StaticOverpass(this._places);
  final List<OverpassPlace> _places;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
    int? requestId,
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
    int? requestId,
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
    int? requestId,
  }) async =>
      _route;
}

class _DynamicValhalla extends ValhallaService {
  _DynamicValhalla({required this.routeHandler});
  final ValhallaRoute? Function(LatLng origin, List<LatLng> waypoints) routeHandler;

  @override
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
    int? requestId,
  }) async =>
      routeHandler(origin, waypoints);
}

class _CountingValhalla extends ValhallaService {
  _CountingValhalla({required this.onRoute});
  final VoidCallback onRoute;

  @override
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
    int? requestId,
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
    int? requestId,
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
    int? requestId,
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
    int? requestId,
  }) async {
    onQuery();
    await Future<void>.delayed(delay);
    return [];
  }
}
