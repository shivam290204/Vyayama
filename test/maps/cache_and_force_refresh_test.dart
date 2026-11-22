import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fitbuddy/features/maps/data/services/circuit_breaker.dart';
import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/domain/models/route_discovery_result.dart';
import 'package:fitbuddy/features/maps/presentation/screens/map_services_check_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_discovery_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// ─── Test HTTP Mocks ────────────────────────────────────────────────────────

class _SimpleMockHttpClient implements HttpClient {
  _SimpleMockHttpClient(this.responseBody, {this.statusCode = 200});
  final String responseBody;
  final int statusCode;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _SimpleMockRequest(responseBody, statusCode);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _SimpleMockRequest(responseBody, statusCode);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SimpleMockRequest implements HttpClientRequest {
  _SimpleMockRequest(this.responseBody, this.statusCode);
  final String responseBody;
  final int statusCode;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async {
    return _SimpleMockResponse(responseBody, statusCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SimpleMockResponse extends Stream<List<int>> implements HttpClientResponse {
  _SimpleMockResponse(this.body, this.statusCode);
  final String body;

  @override
  final int statusCode;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

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

class _MockHttpHeaders implements HttpHeaders {
  final Map<String, String> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = value.toString();
  }

  @override
  String? value(String name) => _headers[name.toLowerCase()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Test Suite ─────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    RouteCache.instance.clear();
  });

  const testCenter = LatLng(51.505, -0.090);

  group('Change 1 & 2: Overpass Caching & Force Refresh', () {
    test('1. Never caches empty Overpass results', () async {
      int queryCount = 0;
      final overpass = OverpassService(
        cache: RouteCache.instance,
        retryBackoff: Duration.zero,
        clientFactory: () {
          queryCount++;
          return _SimpleMockHttpClient(jsonEncode({'elements': []}));
        },
      );

      final key = RouteCache.buildOverpassKey(testCenter, 1500);

      // First query returns empty
      final result1 = await overpass.findNearbyPlaces(
        center: testCenter,
        radiusMeters: 1500,
      );
      expect(result1, isEmpty);

      // Verify NOT cached in RouteCache
      expect(RouteCache.instance.contains(key), isFalse);
      expect(RouteCache.instance.get<List<OverpassPlace>>(key), isNull);

      // Second query must make network request again instead of reading empty cache
      final initialCount = queryCount;
      final result2 = await overpass.findNearbyPlaces(
        center: testCenter,
        radiusMeters: 1500,
      );
      expect(result2, isEmpty);
      expect(queryCount, greaterThan(initialCount));
    });

    test('2. Caches positive (non-empty) Overpass results', () async {
      final validJson = jsonEncode({
        'elements': [
          {
            'type': 'way',
            'id': 1234,
            'center': {'lat': 51.506, 'lon': -0.091},
            'tags': {'leisure': 'park', 'name': 'Green Park'},
          }
        ]
      });

      int queryCount = 0;
      final overpass = OverpassService(
        cache: RouteCache.instance,
        retryBackoff: Duration.zero,
        clientFactory: () {
          queryCount++;
          return _SimpleMockHttpClient(validJson);
        },
      );

      final key = RouteCache.buildOverpassKey(testCenter, 1500);

      final result1 = await overpass.findNearbyPlaces(
        center: testCenter,
        radiusMeters: 1500,
      );
      expect(result1, hasLength(1));
      expect(result1.first.name, equals('Green Park'));

      // Verify cached in RouteCache
      expect(RouteCache.instance.contains(key), isTrue);

      // Second query returns cached list without new network calls
      final countBefore = queryCount;
      final result2 = await overpass.findNearbyPlaces(
        center: testCenter,
        radiusMeters: 1500,
      );
      expect(result2, hasLength(1));
      expect(queryCount, equals(countBefore));
    });

    test('3. forceRefresh bypasses and evicts cache for Overpass', () async {
      final validJson = jsonEncode({
        'elements': [
          {
            'type': 'way',
            'id': 5678,
            'center': {'lat': 51.506, 'lon': -0.091},
            'tags': {'leisure': 'park', 'name': 'St. James Park'},
          }
        ]
      });

      int queryCount = 0;
      final overpass = OverpassService(
        cache: RouteCache.instance,
        retryBackoff: Duration.zero,
        clientFactory: () {
          queryCount++;
          return _SimpleMockHttpClient(validJson);
        },
      );

      // First query primes cache
      await overpass.findNearbyPlaces(
        center: testCenter,
        radiusMeters: 1500,
      );
      expect(queryCount, greaterThan(0));
      final countAfterPrime = queryCount;

      // forceRefresh: true must make new requests
      final refreshed = await overpass.findNearbyPlaces(
        center: testCenter,
        radiusMeters: 1500,
        forceRefresh: true,
      );
      expect(refreshed, hasLength(1));
      expect(queryCount, greaterThan(countAfterPrime));
    });

    test('4. forceRefresh resets circuit breaker cooldown', () async {
      final circuitBreaker = ServiceCircuitBreaker(
        serviceName: 'OpenStreetMap Places',
        failureThreshold: 2,
        cooldownDuration: const Duration(minutes: 5),
      );

      // Trip the circuit breaker
      circuitBreaker.recordFailure();
      circuitBreaker.recordFailure();
      expect(circuitBreaker.isOpen, isTrue);

      final overpass = OverpassService(
        cache: RouteCache.instance,
        circuitBreaker: circuitBreaker,
        clientFactory: () => _SimpleMockHttpClient('{}'),
      );

      // Normal call fails immediately due to open circuit breaker
      expect(
        () => overpass.findNearbyPlaces(center: testCenter, radiusMeters: 1500),
        throwsA(isA<CircuitBreakerOpenException>()),
      );

      // forceRefresh clears the circuit breaker and does NOT throw CircuitBreakerOpenException
      // (it will proceed and execute)
      expect(circuitBreaker.isOpen, isTrue);
      // When forceRefresh is true, breaker is reset
      try {
        await overpass.findNearbyPlaces(
          center: testCenter,
          radiusMeters: 1500,
          forceRefresh: true,
        );
      } catch (e) {
        // Must NOT be CircuitBreakerOpenException!
        expect(e, isNot(isA<CircuitBreakerOpenException>()));
      }
      expect(circuitBreaker.isOpen, isFalse);
    });

    test('5. Cooldown never blocks a user-forced refresh', () async {
      final overpass = OverpassService(
        cache: RouteCache.instance,
        clientFactory: () => _SimpleMockHttpClient('{}', statusCode: 500),
      );

      // Cause endpoint cooldown
      try {
        await overpass.findNearbyPlaces(center: testCenter, radiusMeters: 1500);
      } catch (_) {}

      // A user-forced refresh should reset cooldowns and attempt queries
      int attemptedQueries = 0;
      final refreshingOverpass = OverpassService(
        cache: RouteCache.instance,
        clientFactory: () {
          attemptedQueries++;
          return _SimpleMockHttpClient(jsonEncode({'elements': []}));
        },
      );

      await refreshingOverpass.findNearbyPlaces(
        center: testCenter,
        radiusMeters: 1500,
        forceRefresh: true,
      );
      expect(attemptedQueries, greaterThan(0));
    });
  });

  group('Change 3: Inline Empty Reason formatting', () {
    test('6. formatInlineEmptyReason formats all reasons in calm, plain language', () {
      final noPlacesDiag = RouteDiscoveryDiagnostics(
        timestamp: DateTime.now(),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
        searchRadiusMeters: 5000,
        overpassStatus: 'zero_elements',
        finalRouteCount: 0,
        emptyReason: EmptyReason.noPlacesFound,
      );
      expect(
        formatInlineEmptyReason(noPlacesDiag),
        equals('Overpass returned 0 places within 5 km'),
      );

      final noCandidatesDiag = RouteDiscoveryDiagnostics(
        timestamp: DateTime.now(),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
        searchRadiusMeters: 3000,
        overpassStatus: 'OK',
        finalRouteCount: 0,
        emptyReason: EmptyReason.noCandidates,
      );
      expect(
        formatInlineEmptyReason(noCandidatesDiag),
        equals('Found places nearby, but none met distance criteria for route generation'),
      );

      final allFilteredDiag = RouteDiscoveryDiagnostics(
        timestamp: DateTime.now(),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
        searchRadiusMeters: 5000,
        overpassStatus: 'OK',
        finalRouteCount: 0,
        emptyReason: EmptyReason.allRoutesFiltered,
      );
      expect(
        formatInlineEmptyReason(allFilteredDiag),
        equals('Generated routes were too short (under 300 m) or duplicates'),
      );

      final genuineEmptyDiag = RouteDiscoveryDiagnostics(
        timestamp: DateTime.now(),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
        searchRadiusMeters: 5000,
        overpassStatus: 'OK',
        finalRouteCount: 0,
        emptyReason: EmptyReason.genuineEmpty,
      );
      expect(
        formatInlineEmptyReason(genuineEmptyDiag),
        equals('No walkable routes could be formed from nearby map data'),
      );
    });
  });

  group('Change 4: Known-Park Pipeline Test Report', () {
    test('7. KnownParkPipelineReport correctly reports benchmark vs search center outcomes', () {
      final report = KnownParkPipelineReport(
        points: [
          const KnownParkTestPointResult(
            name: 'Central Park (New York)',
            coords: LatLng(40.7829, -73.9654),
            placesFound: 15,
            candidates: 8,
            valhallaSuccesses: 6,
            routes: 4,
          ),
          const KnownParkTestPointResult(
            name: 'Lodhi Garden (Delhi)',
            coords: LatLng(28.5933, 77.2197),
            placesFound: 10,
            candidates: 6,
            valhallaSuccesses: 4,
            routes: 3,
          ),
          const KnownParkTestPointResult(
            name: 'Your Search Center',
            coords: LatLng(28.7041, 77.1025),
            placesFound: 0,
            candidates: 0,
            valhallaSuccesses: 0,
            routes: 0,
            distanceFromGpsFormatted: '15 m',
          ),
        ],
        summary: 'Pipeline works at known parks, but found no routes at your search center.',
        distanceSearchCenterToGpsFormatted: '15 m',
      );

      final text = report.toPlainText();
      expect(text, contains('Central Park (New York)'));
      expect(text, contains('Lodhi Garden (Delhi)'));
      expect(text, contains('Your Search Center'));
      expect(text, contains('Pipeline works at known parks, but found no routes at your search center.'));
      expect(text, contains('Distance (Search Center to GPS): 15 m'));
    });
  });

  group('Change 6: Gate diagnostics and fallback', () {
    test('8. candidateRejectionReason serializes in toPlainText()', () {
      final diag = RouteDiscoveryDiagnostics(
        timestamp: DateTime.now(),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
        searchRadiusMeters: 5000,
        overpassStatus: 'OK',
        candidatesCount: 0,
        candidateRejectionReason: 'distance_cluster_under_250m',
        finalRouteCount: 0,
        emptyReason: EmptyReason.noCandidates,
      );

      expect(diag.candidateRejectionReason, equals('distance_cluster_under_250m'));
      final plainText = diag.toPlainText();
      expect(plainText, contains('Gate Rejection Reason: distance_cluster_under_250m'));
    });

    test('9. ForceRefreshNotifier triggers and consumes properly', () {
      final notifier = ForceRefreshNotifier();
      expect(notifier.checkAndConsume(), isFalse);

      notifier.trigger();
      expect(notifier.checkAndConsume(), isTrue);

      // Second check without new trigger returns false
      expect(notifier.checkAndConsume(), isFalse);
    });
  });
}
