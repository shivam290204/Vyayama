import 'dart:async';
import 'package:fitbuddy/features/maps/data/services/circuit_breaker.dart';
import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';
import 'package:fitbuddy/features/maps/data/services/map_service_config.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/domain/services/map_provider_adapter.dart';
import 'package:fitbuddy/features/maps/presentation/screens/maps_screen.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('1. MapServiceConfig & Endpoint Configuration Tests', () {
    test('Default endpoints resolve to development public servers without crashing', () {
      expect(MapServiceConfig.tileUrlTemplate, contains('tile.openstreetmap.org'));
      expect(MapServiceConfig.overpassUrls, isNotEmpty);
      expect(MapServiceConfig.overpassUrls.first, contains('openstreetmap.fr'));
      expect(MapServiceConfig.valhallaUrl, contains('valhalla1.openstreetmap.de'));
      expect(MapServiceConfig.nominatimUrl, contains('nominatim.openstreetmap.org'));
      expect(MapServiceConfig.isUsingPublicEndpoints, isTrue);
    });

    test('Overpass URLs prioritize the reliable openstreetmap.fr mirror first', () {
      final mirrors = MapServiceConfig.overpassUrls;
      expect(mirrors.first, equals('https://overpass.openstreetmap.fr/api/interpreter'));
    });
  });

  group('2. ServiceCircuitBreaker Comprehensive Unit Tests', () {
    test('Starts closed and passes calls through', () {
      final breaker = ServiceCircuitBreaker(
        serviceName: 'Test Service',
        failureThreshold: 3,
        cooldownDuration: const Duration(seconds: 60),
      );

      expect(breaker.state, equals(CircuitBreakerState.closed));
      expect(breaker.isOpen, isFalse);
      expect(() => breaker.protect(), returnsNormally);
    });

    test('Trips to open state after consecutive failures reach threshold', () {
      var simulatedTime = DateTime(2026, 11, 6, 12, 0, 0);
      final breaker = ServiceCircuitBreaker(
        serviceName: 'Test Service',
        failureThreshold: 3,
        cooldownDuration: const Duration(seconds: 60),
        clock: () => simulatedTime,
      );

      breaker.recordFailure();
      expect(breaker.state, equals(CircuitBreakerState.closed));
      expect(breaker.failureCount, equals(1));

      breaker.recordFailure();
      expect(breaker.failureCount, equals(2));
      expect(breaker.isOpen, isFalse);

      breaker.recordFailure(); // Threshold reached
      expect(breaker.failureCount, equals(3));
      expect(breaker.state, equals(CircuitBreakerState.open));
      expect(breaker.isOpen, isTrue);

      expect(
        () => breaker.protect(),
        throwsA(isA<CircuitBreakerOpenException>()
            .having((e) => e.serviceName, 'serviceName', 'Test Service')
            .having((e) => e.cooldownRemaining.inSeconds, 'cooldownRemaining', 60)),
      );
    });

    test('Success resets consecutive failures counter', () {
      final breaker = ServiceCircuitBreaker(
        serviceName: 'Test Service',
        failureThreshold: 3,
      );

      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.failureCount, equals(2));

      breaker.recordSuccess();
      expect(breaker.failureCount, equals(0));
      expect(breaker.state, equals(CircuitBreakerState.closed));
    });

    test('Transitions to halfOpen after cooldown expires and allows probe request', () {
      var simulatedTime = DateTime(2026, 11, 6, 12, 0, 0);
      final breaker = ServiceCircuitBreaker(
        serviceName: 'Test Service',
        failureThreshold: 2,
        cooldownDuration: const Duration(seconds: 60),
        clock: () => simulatedTime,
      );

      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isOpen, isTrue);

      // Advance time by 61 seconds (past cooldown)
      simulatedTime = simulatedTime.add(const Duration(seconds: 61));
      expect(breaker.state, equals(CircuitBreakerState.halfOpen));
      expect(breaker.isOpen, isFalse); // Allows trial probe
      expect(() => breaker.protect(), returnsNormally);

      // Trial probe succeeds -> resets to closed
      breaker.recordSuccess();
      expect(breaker.state, equals(CircuitBreakerState.closed));
    });
  });

  group('3. Map Provider Adapter Architecture & Mapbox Tests', () {
    test('OsmMapProviderAdapter is enabled and provides compliant attribution', () {
      const adapter = OsmMapProviderAdapter();
      expect(adapter.id, equals('osm'));
      expect(adapter.isEnabled, isTrue);
      expect(adapter.tileUrlTemplate, contains('tile.openstreetmap.org'));
      expect(adapter.tileHeaders['User-Agent'], equals(MapApiConfig.userAgent));
      expect(adapter.attributionText, contains('OpenStreetMap'));
    });

    test('MapboxProviderAdapter is disabled by default when token is not injected', () {
      const adapter = MapboxProviderAdapter();
      expect(adapter.id, equals('mapbox'));
      // In normal tests without --dart-define=ENABLE_MAPBOX=true, it is disabled
      expect(adapter.isEnabled, isFalse);
      expect(adapter.attributionText, contains('Mapbox'));
      expect(adapter.attributionText, contains('OpenStreetMap'));
      expect(adapter.tileUrlTemplate, contains('api.mapbox.com'));
    });
  });

  group('4. Non-blocking Tile Error Chip UI & Retry Action Tests', () {
    testWidgets('Renders non-blocking tile error chip with working Retry button',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            discoveredRoutesProvider.overrideWith((ref) => Stream.value([])),
            userLocationStateProvider.overrideWithValue(
              const UserLocationState(
                status: UserLocationStatus.available,
                position: LatLng(28.715, 77.170),
                accuracyMeters: 5.0,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MapsScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially no tile error banner
      expect(find.byKey(const Key('tile_error_banner')), findsNothing);

      // Trigger tile error state via testing helper
      final state = tester.state(find.byType(MapsScreen)) as dynamic;
      // ignore: avoid_dynamic_calls
      state.triggerTileErrorForTesting();
      await tester.pump();

      // Now the non-blocking tile error chip is visible
      expect(find.byKey(const Key('tile_error_banner')), findsOneWidget);
      expect(find.text('Map tiles temporarily unavailable.'), findsOneWidget);
      expect(find.byKey(const Key('tile_error_retry_button')), findsOneWidget);

      // Tap Retry button
      await tester.tap(find.byKey(const Key('tile_error_retry_button')));
      await tester.pump();

      // Chip is dismissed and tile layer is triggered to reload
      expect(find.byKey(const Key('tile_error_banner')), findsNothing);
    });
  });
}
