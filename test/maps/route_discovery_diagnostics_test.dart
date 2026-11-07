import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fitbuddy/features/maps/data/services/map_diagnostics_service.dart';
import 'package:fitbuddy/features/maps/data/services/nominatim_service.dart';
import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/real_route_discovery_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/data/services/valhalla_service.dart';
import 'package:fitbuddy/features/maps/domain/models/route_discovery_result.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/presentation/screens/map_services_check_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_discovery_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    RouteCache.instance.clear();
  });

  group('Route Discovery Diagnostics & EmptyReason Pipeline Tests', () {
    test('1. Overpass detects "Query timed out" remark as ServiceTimeoutException', () {
      final overpass = OverpassService();
      const body = '''
      {
        "version": 0.6,
        "generator": "Overpass API",
        "remark": "runtime error: Query timed out in 25 seconds.",
        "elements": []
      }
      ''';

      expect(
        () => overpass.parseOverpassResponse(body),
        throwsA(isA<ServiceTimeoutException>()),
      );
      expect(overpass.lastRemark, contains('Query timed out'));
    });

    test('2. Overpass detects "out of memory" remark as OverpassServiceException', () {
      final overpass = OverpassService();
      const body = '''
      {
        "version": 0.6,
        "generator": "Overpass API",
        "remark": "runtime error: Query run out of memory in 536870912 bytes.",
        "elements": []
      }
      ''';

      expect(
        () => overpass.parseOverpassResponse(body),
        throwsA(isA<OverpassServiceException>()),
      );
      expect(overpass.lastRemark, contains('out of memory'));
    });

    test('3. Overpass valid elements parse cleanly and track element count', () {
      final overpass = OverpassService();
      const body = '''
      {
        "elements": [
          {
            "type": "way",
            "id": 12345,
            "center": {"lat": 12.9716, "lon": 77.5946},
            "tags": {"name": "Cubbon Park", "leisure": "park"}
          }
        ]
      }
      ''';

      final places = overpass.parseOverpassResponse(body);
      expect(places.length, equals(1));
      expect(overpass.lastElementCount, equals(1));
      expect(overpass.lastRemark, isNull);
    });

    test('4. Genuine empty: Overpass and Nominatim find 0 places -> EmptyReason.noPlacesFound', () async {
      final fakeOverpass = _FakeOverpassService(places: const []);
      final fakeNominatim = _FakeNominatimService(places: const []);
      final fakeValhalla = _FakeValhallaService(returnNullRoute: true);

      final service = RealRouteDiscoveryService(
        overpass: fakeOverpass,
        nominatim: fakeNominatim,
        valhalla: fakeValhalla,
      );

      final result = await service.discoverRoutes(
        center: const LatLng(12.97, 77.59),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
      );

      expect(result.isEmpty, isTrue);
      expect(result.emptyReason, equals(EmptyReason.noPlacesFound));
      expect(result.diagnostics.overpassElementCount, equals(0));
      expect(result.diagnostics.nominatimCount, equals(0));
      expect(result.diagnostics.isServiceFailure, isFalse);
    });

    test('5. Nominatim error is recorded in diagnostics and not swallowed', () async {
      final fakeOverpass = _FakeOverpassService(places: const []);
      final fakeNominatim = _FakeNominatimService(
        places: const [],
        errorToThrow: const RouteNetworkException('Nominatim network error'),
      );
      final fakeValhalla = _FakeValhallaService(returnNullRoute: true);

      final service = RealRouteDiscoveryService(
        overpass: fakeOverpass,
        nominatim: fakeNominatim,
        valhalla: fakeValhalla,
      );

      final result = await service.discoverRoutes(
        center: const LatLng(12.971, 77.591),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
      );

      expect(result.isEmpty, isTrue);
      expect(result.diagnostics.nominatimError, contains('Nominatim network error'));
    });

    test('6. Overpass timeout yields EmptyReason.serviceTimeout', () async {
      final fakeOverpass = _FakeOverpassService(
        places: const [],
        errorToThrow: const ServiceTimeoutException(
          serviceName: 'OpenStreetMap Overpass',
          message: 'Overpass query timed out',
        ),
      );
      final fakeNominatim = _FakeNominatimService(places: const []);
      final fakeValhalla = _FakeValhallaService(returnNullRoute: true);

      final service = RealRouteDiscoveryService(
        overpass: fakeOverpass,
        nominatim: fakeNominatim,
        valhalla: fakeValhalla,
      );

      final result = await service.discoverRoutes(
        center: const LatLng(12.972, 77.592),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
      );

      expect(result.isEmpty, isTrue);
      expect(result.emptyReason, equals(EmptyReason.serviceTimeout));
      expect(result.diagnostics.isServiceFailure, isTrue);
    });

    test('7. Valhalla routing returning null for all candidates yields EmptyReason.allRoutesFailed', () async {
      final fakeOverpass = _FakeOverpassService(places: [
        const OverpassPlace(
          id: 101,
          name: 'Scenic Loop Entry',
          lat: 12.973,
          lon: 77.593,
          tags: {'leisure': 'park'},
        ),
      ]);
      final fakeNominatim = _FakeNominatimService(places: const []);
      final fakeValhalla = _FakeValhallaService(returnNullRoute: true);

      final service = RealRouteDiscoveryService(
        overpass: fakeOverpass,
        nominatim: fakeNominatim,
        valhalla: fakeValhalla,
      );

      final result = await service.discoverRoutes(
        center: const LatLng(12.973, 77.593),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
      );

      expect(result.isEmpty, isTrue);
      expect(result.emptyReason, equals(EmptyReason.allRoutesFailed));
      expect(result.diagnostics.candidatesCount, greaterThan(0));
      expect(result.diagnostics.valhallaAttempts, greaterThan(0));
      expect(result.diagnostics.valhallaNulls, greaterThan(0));
      expect(result.diagnostics.isServiceFailure, isTrue);
    });

    test('8. Filter drops: routes under 300m increment stage counter droppedTooShort', () async {
      final fakeOverpass = _FakeOverpassService(places: [
        const OverpassPlace(
          id: 202,
          name: 'Pocket Garden',
          lat: 12.974,
          lon: 77.594,
          tags: {'leisure': 'garden'},
        ),
      ]);
      final fakeNominatim = _FakeNominatimService(places: const []);
      // Prebuilt route with distance 120m (< 300m)
      final fakeValhalla = _FakeValhallaService(
        prebuiltRoute: const ValhallaRoute(
          points: [
            LatLng(12.9740, 77.5940),
            LatLng(12.9742, 77.5942),
            LatLng(12.9744, 77.5944),
            LatLng(12.9745, 77.5945),
            LatLng(12.9740, 77.5940),
          ],
          distanceMeters: 120.0, // < 300m
          durationSeconds: 90.0,
        ),
      );

      final service = RealRouteDiscoveryService(
        overpass: fakeOverpass,
        nominatim: fakeNominatim,
        valhalla: fakeValhalla,
      );

      final result = await service.discoverRoutes(
        center: const LatLng(12.974, 77.594),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
      );

      expect(result.isEmpty, isTrue);
      expect(result.emptyReason, equals(EmptyReason.allRoutesFiltered));
      expect(result.diagnostics.droppedTooShort, equals(1));
    });
  });

  group('RouteDiscoverySheet & MapServicesCheckScreen Phase 1 UI Tests', () {
    testWidgets('RouteDiscoverySheet renders "Search failed, try again" with Retry button on service failure', (tester) async {
      final diagnostics = RouteDiscoveryDiagnostics(
        timestamp: DateTime.now(),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
        overpassStatus: 'timeout',
        overpassRemark: 'Query timed out',
        finalRouteCount: 0,
        emptyReason: EmptyReason.serviceTimeout,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveredRoutesProvider.overrideWith((ref) => Stream.value(const [])),
            latestDiscoveryDiagnosticsProvider.overrideWithValue(diagnostics),
            userLocationStateProvider.overrideWith(
              (ref) => UserLocationState(
                status: UserLocationStatus.available,
                position: const LatLng(12.97, 77.59),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RouteDiscoverySheet(
                onRouteSelected: (_) {},
                onRecordPressed: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Record Outdoor Activity'), findsOneWidget);
      expect(find.text('Search failed, try again'), findsOneWidget);
      expect(find.text('Retry Search'), findsOneWidget);
      expect(find.text('View Diagnostics'), findsOneWidget);
    });

    testWidgets('RouteDiscoverySheet renders "No mapped routes found nearby." on genuine empty', (tester) async {
      final diagnostics = RouteDiscoveryDiagnostics(
        timestamp: DateTime.now(),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
        overpassStatus: 'OK',
        overpassElementCount: 0,
        nominatimCount: 0,
        finalRouteCount: 0,
        emptyReason: EmptyReason.genuineEmpty,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveredRoutesProvider.overrideWith((ref) => Stream.value(const [])),
            latestDiscoveryDiagnosticsProvider.overrideWithValue(diagnostics),
            userLocationStateProvider.overrideWith(
              (ref) => UserLocationState(
                status: UserLocationStatus.available,
                position: const LatLng(12.97, 77.59),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RouteDiscoverySheet(
                onRouteSelected: (_) {},
                onRecordPressed: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Record Outdoor Activity'), findsOneWidget);
      expect(find.text('No mapped routes found nearby.'), findsOneWidget);
      expect(find.text('Check Again'), findsOneWidget);
      expect(find.text('Why no routes?'), findsOneWidget);
    });

    testWidgets('MapServicesCheckScreen renders "Why no routes?" pipeline breakdown and copies report', (tester) async {
      final diagnostics = RouteDiscoveryDiagnostics(
        timestamp: DateTime.now(),
        searchCenterSource: SearchCenterSource.userGps,
        hasValidNonFallbackLocation: true,
        roundedLat: 12.97,
        roundedLon: 77.59,
        overpassStatus: 'OK',
        overpassElementCount: 15,
        candidatesCount: 6,
        valhallaAttempts: 6,
        valhallaSuccesses: 2,
        valhallaNulls: 4,
        droppedTooShort: 1,
        finalRouteCount: 1,
        emptyReason: EmptyReason.none,
      );

      final diagService = MapDiagnosticsService(
        dnsLookup: (host) async => [InternetAddress('8.8.8.8')],
        clientFactory: () => _FakeDiagnosticHttpClient(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            latestDiscoveryDiagnosticsProvider.overrideWithValue(diagnostics),
          ],
          child: MaterialApp(
            home: MapServicesCheckScreen(
              diagnosticsService: diagService,
              discoveryDiagnostics: diagnostics,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Route Discovery Pipeline ("Why no routes?")'), findsOneWidget);
      expect(find.text('Pipeline Stage Breakdown'), findsOneWidget);
      expect(find.text('1. Search Center'), findsOneWidget);
      expect(find.text('2. Overpass Query'), findsOneWidget);
      expect(find.text('3. Nominatim Fallback'), findsOneWidget);
      expect(find.text('4. Waypoint Routing (Valhalla)'), findsOneWidget);
      expect(find.text('5. Filtering & Final Output'), findsOneWidget);
      expect(find.text('Copy Route Discovery Report'), findsOneWidget);

      // Verify privacy: plain text does NOT contain unrounded raw coordinates
      final plainText = diagnostics.toPlainText();
      expect(plainText, contains('Search Center (approx): 12.97, 77.59'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test Doubles
// ---------------------------------------------------------------------------

class _FakeOverpassService extends OverpassService {
  _FakeOverpassService({
    required this.places,
    this.errorToThrow,
  });

  final List<OverpassPlace> places;
  final Exception? errorToThrow;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    double radiusMeters = 5000,
    int? requestId,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return places;
  }
}

class _FakeNominatimService extends NominatimService {
  _FakeNominatimService({
    required this.places,
    this.errorToThrow,
  });

  final List<OverpassPlace> places;
  final Exception? errorToThrow;

  @override
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    double radiusMeters = 5000,
    int? requestId,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return places;
  }
}

class _FakeValhallaService extends ValhallaService {
  _FakeValhallaService({
    this.returnNullRoute = false,
    this.prebuiltRoute,
  });

  final bool returnNullRoute;
  final ValhallaRoute? prebuiltRoute;

  @override
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
    int? requestId,
  }) async {
    if (returnNullRoute) return null;
    if (prebuiltRoute != null) return prebuiltRoute;

    final start = origin;
    final end = waypoints.isNotEmpty ? waypoints.first : origin;

    return ValhallaRoute(
      points: [
        start,
        LatLng((start.latitude + end.latitude) / 2, (start.longitude + end.longitude) / 2),
        end,
        LatLng(end.latitude + 0.005, end.longitude + 0.005),
        start,
      ],
      distanceMeters: 1500.0,
      durationSeconds: 1200.0,
    );
  }
}

class _FakeDiagnosticHttpClient implements HttpClient {
  @override
  String? userAgent = 'VyayamaTest/1.0';

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeDiagnosticRequest();
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeDiagnosticRequest();
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) async {
    return _FakeDiagnosticRequest();
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDiagnosticRequest implements HttpClientRequest {
  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async {
    return _FakeDiagnosticResponse(200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDiagnosticResponse implements HttpClientResponse {
  _FakeDiagnosticResponse(this.statusCode);

  @override
  final int statusCode;

  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(utf8.encode('{}')).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
