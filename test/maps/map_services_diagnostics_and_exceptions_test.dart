import 'dart:async';
import 'dart:io';

import 'package:fitbuddy/features/maps/data/services/map_diagnostics_service.dart';
import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/presentation/screens/map_services_check_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/route_discovery_sheet.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('1. Distinct Error Classification Matrix & Sheet Mapping Tests', () {
    testWidgets('DeviceOfflineException renders No Internet Connection with wifi_off icon',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(const DeviceOfflineException()),
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
      expect(find.text('Unable to reach routing services. Please verify your connection.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('ServiceUnreachableException renders Service Unreachable without claiming offline',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(
                    const ServiceUnreachableException(
                      serviceName: 'OpenStreetMap',
                      host: 'overpass-api.de',
                    ),
                  ),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OpenStreetMap Unreachable'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('No Internet Connection'), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });

    testWidgets('ServiceTimeoutException renders Mapping service timed out',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(
                    const ServiceTimeoutException(
                      serviceName: 'Valhalla Routing',
                      duration: Duration(seconds: 10),
                    ),
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
      expect(find.text('No Internet Connection'), findsNothing);
    });

    testWidgets('ServiceErrorException renders service unavailable with server error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(
                    const ServiceErrorException(
                      serviceName: 'Custom Gateway',
                      statusCode: 503,
                    ),
                  ),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Gateway Unavailable'), findsOneWidget);
      expect(find.byIcon(Icons.dns_outlined), findsOneWidget);
    });

    testWidgets('BadResponseException renders Unexpected Response without raw exception text',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              overrides: [
                discoveredRoutesProvider.overrideWith(
                  (ref) => Stream.error(
                    const BadResponseException(
                      serviceName: 'OpenStreetMap',
                      statusCode: 400,
                    ),
                  ),
                ),
              ],
              child: RouteDiscoverySheet(onRouteSelected: (_) {}, onRecordPressed: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unexpected Response'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.textContaining('Exception:'), findsNothing);
    });
  });

  group('2. Overpass Mirror Aggregation Tests', () {
    test('OverpassService aggregates all failed mirror attempts into lastMirrorAttempts', () async {
      final mirrors = [
        'https://mirror1.example.com/api',
        'https://mirror2.example.com/api',
      ];

      final service = OverpassService(
        endpoints: mirrors,
        retryBackoff: Duration.zero,
        isOfflineProbe: () async => false, // Online, so mirrors fail as server errors
        clientFactory: () {
          return _FakeFailingHttpClient(statusCode: 502);
        },
      );

      try {
        await service.findNearbyPlaces(
          center: const LatLng(28.6139, 77.2090),
          radiusMeters: 1000,
        );
        fail('Expected exception');
      } on AllOverpassMirrorsFailedException catch (e) {
        expect(e.attempts.length, equals(4)); // 2 attempts across 2 endpoints
        expect(service.lastMirrorAttempts.length, equals(4));
        expect(service.lastMirrorAttempts.every((a) => a.statusCode == 502), isTrue);
        expect(service.lastMirrorAttempts.every((a) => !a.succeeded), isTrue);
      }
    });

    test('Confirmed offline state throws DeviceOfflineException immediately without probing all mirrors', () async {
      final mirrors = [
        'https://m1.example.com',
        'https://m2.example.com',
        'https://m3.example.com',
      ];

      int clientCreationCount = 0;
      final service = OverpassService(
        endpoints: mirrors,
        isOfflineProbe: () async => true, // Explicitly offline
        clientFactory: () {
          clientCreationCount++;
          return _FakeFailingHttpClient(statusCode: 200);
        },
      );

      expect(
        () => service.findNearbyPlaces(
          center: const LatLng(28.6139, 77.2090),
          radiusMeters: 1000,
        ),
        throwsA(isA<DeviceOfflineException>()),
      );

      expect(clientCreationCount, equals(0)); // Fast-path: didn't make any HTTP requests!
    });
  });

  group('3. MapDiagnosticsService Probes & Sanitization Tests', () {
    test('Diagnostics report formats clean plain text without user GPS coordinates', () async {
      final report = MapDiagnosticsReport(
        timestamp: DateTime.utc(2026, 11, 6, 12, 0, 0),
        deviceOnline: true,
        results: const [
          ServiceProbeResult(
            serviceName: 'Neutral DNS (Google)',
            host: 'dns.google',
            isReachable: true,
            latency: Duration(milliseconds: 32),
            statusCode: null,
            errorType: DiagnosticsErrorType.none,
            details: 'Resolved 2 IP(s)',
          ),
          ServiceProbeResult(
            serviceName: 'OSM Map Tiles',
            host: 'tile.openstreetmap.org',
            isReachable: true,
            latency: Duration(milliseconds: 75),
            statusCode: 200,
            errorType: DiagnosticsErrorType.none,
            details: 'Tile 0/0/0 rendered',
          ),
          ServiceProbeResult(
            serviceName: 'Overpass (overpass-api.de)',
            host: 'overpass-api.de',
            isReachable: false,
            latency: Duration(milliseconds: 5000),
            statusCode: null,
            errorType: DiagnosticsErrorType.timeout,
            details: 'Request timed out after 5s',
          ),
        ],
      );

      final text = report.toPlainText();

      // Privacy audit: Ensure no user coordinates are ever leaked
      expect(text, isNot(contains('latitude')));
      expect(text, isNot(contains('longitude')));
      expect(text, isNot(contains('28.6139')));
      expect(text, isNot(contains('77.2090')));

      // Content verification
      expect(text, contains('=== Vyayama Map Services Check ==='));
      expect(text, contains('General Internet: CONNECTED'));
      expect(text, contains('Neutral DNS (Google)'));
      expect(text, contains('OK (200)'));
      expect(text, contains('FAIL (Timeout)'));
    });

    test('MapDiagnosticsService runs probes using injected clients and classifies errors', () async {
      final diagnostics = MapDiagnosticsService(
        dnsLookup: (host) async => [InternetAddress('8.8.8.8')],
        clientFactory: () => _FakeDiagnosticHttpClient(),
      );

      final report = await diagnostics.runDiagnostics();

      expect(report.deviceOnline, isTrue);
      expect(report.results.length, greaterThanOrEqualTo(5));

      final dnsResult = report.results.firstWhere((r) => r.serviceName.contains('Neutral DNS'));
      expect(dnsResult.isReachable, isTrue);
      expect(dnsResult.errorType, equals(DiagnosticsErrorType.none));
    });
  });

  group('4. MapServicesCheckScreen Widget Tests', () {
    testWidgets('Renders all probe results and copies report to clipboard', (tester) async {
      final diagnostics = MapDiagnosticsService(
        dnsLookup: (host) async => [InternetAddress('8.8.8.8')],
        clientFactory: () => _FakeDiagnosticHttpClient(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MapServicesCheckScreen(diagnosticsService: diagnostics),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Map Services Check'), findsOneWidget);
      expect(find.text('General Internet: Online'), findsOneWidget);
      expect(find.text('Service Endpoints'), findsOneWidget);
      expect(find.byIcon(Icons.copy_all_rounded), findsOneWidget);
      expect(find.text('Copy Diagnostics Report'), findsOneWidget);

      // Tap Copy Report button
      await tester.tap(find.text('Copy Diagnostics Report'));
      await tester.pump();

      expect(find.text('Diagnostics report copied to clipboard'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test Doubles
// ---------------------------------------------------------------------------

class _FakeFailingHttpClient implements HttpClient {
  _FakeFailingHttpClient({required this.statusCode});
  final int statusCode;

  @override
  String? userAgent = 'VyayamaTest/1.0';

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(statusCode);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDiagnosticHttpClient implements HttpClient {
  @override
  String? userAgent = 'VyayamaTest/1.0';

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest(200);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(200);
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) async {
    return _FakeHttpClientRequest(204);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this.statusCode);
  final int statusCode;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(statusCode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode);

  @override
  final int statusCode;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value([123, 125]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
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
