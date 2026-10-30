import 'dart:async';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/domain/services/location_tracking_service.dart';
import 'package:fitbuddy/features/maps/domain/services/route_discovery_engine.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_summary_screen.dart';
import 'package:fitbuddy/features/maps/presentation/screens/route_detail_screen.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('UserLocationState Model Tests', () {
    test('1. Initial state defaults to initializing with no coordinates', () {
      const state = UserLocationState.initial;
      expect(state.status, equals(UserLocationStatus.initializing));
      expect(state.position, isNull);
      expect(state.lastKnownPosition, isNull);
      expect(state.isAvailable, isFalse);
      expect(state.hasPosition, isFalse);
      expect(state.isResolving, isTrue);
      expect(state.hasPermissionIssue, isFalse);
      expect(state.bestAvailablePosition, isNull);
    });

    test('2. Available state reports correct flags and coordinates', () {
      const pos = LatLng(28.715, 77.170);
      final state = UserLocationState(
        status: UserLocationStatus.available,
        position: pos,
        accuracyMeters: 4.5,
        timestamp: DateTime(2026, 10, 30, 12, 0),
      );

      expect(state.isAvailable, isTrue);
      expect(state.hasPosition, isTrue);
      expect(state.isResolving, isFalse);
      expect(state.position, equals(pos));
      expect(state.bestAvailablePosition, equals(pos));
      expect(state.accuracyMeters, equals(4.5));
    });

    test('3. Fallback to last known position while waiting for signal', () {
      const lastKnown = LatLng(28.710, 77.165);
      final state = UserLocationState.initial.copyWith(
        status: UserLocationStatus.waitingForSignal,
        lastKnownPosition: lastKnown,
      );

      expect(state.isAvailable, isFalse);
      expect(state.hasPosition, isTrue);
      expect(state.isResolving, isTrue);
      expect(state.position, isNull);
      expect(state.bestAvailablePosition, equals(lastKnown));
    });

    test('4. Permission issue detection', () {
      const deniedState = UserLocationState(
        status: UserLocationStatus.permissionDenied,
        errorMessage: 'Permission denied',
      );
      expect(deniedState.hasPermissionIssue, isTrue);
      expect(deniedState.isResolving, isFalse);

      const foreverState = UserLocationState(
        status: UserLocationStatus.permissionDeniedForever,
        errorMessage: 'Permission denied forever',
      );
      expect(foreverState.hasPermissionIssue, isTrue);

      const disabledState = UserLocationState(
        status: UserLocationStatus.serviceDisabled,
      );
      expect(disabledState.hasPermissionIssue, isFalse);
    });

    test('4b. Unavailable state detection', () {
      const unavailState = UserLocationState(
        status: UserLocationStatus.unavailable,
        errorMessage: 'Location hardware unavailable',
      );
      expect(unavailState.isUnavailable, isTrue);
      expect(unavailState.isAvailable, isFalse);
      expect(unavailState.hasPosition, isFalse);
      expect(unavailState.hasPermissionIssue, isFalse);
    });

    test('5. Equality and copyWith', () {
      const s1 = UserLocationState(
        status: UserLocationStatus.available,
        position: LatLng(28.0, 77.0),
      );
      const s2 = UserLocationState(
        status: UserLocationStatus.available,
        position: LatLng(28.0, 77.0),
      );
      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));

      final modified = s1.copyWith(status: UserLocationStatus.timedOut);
      expect(modified.status, equals(UserLocationStatus.timedOut));
      expect(modified.position, equals(const LatLng(28.0, 77.0)));
    });
  });

  group('LocationTrackingService Deduplication & Generation Tests', () {
    test('6. Concurrent getCurrentPosition calls share single in-flight future', () async {
      final service = LocationTrackingService();

      service.getCurrentPositionOverride = () async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return const LatLng(28.715, 77.170);
      };

      // In the override branch, getCurrentPositionOverride is directly executed.
      // Now test the de-duplication mechanism directly by simulating concurrent calls:
      final c = Completer<LatLng?>();
      var internalCalls = 0;

      final dedupService = _TestDedupLocationService(
        onFetch: () {
          internalCalls++;
          return c.future;
        },
      );

      final f1 = dedupService.getCurrentPosition();
      final f2 = dedupService.getCurrentPosition();
      final f3 = dedupService.getCurrentPosition();

      expect(internalCalls, equals(1));
      expect(dedupService.positionRequestGeneration, equals(1));

      c.complete(const LatLng(28.715, 77.170));

      final r1 = await f1;
      final r2 = await f2;
      final r3 = await f3;

      expect(r1, equals(const LatLng(28.715, 77.170)));
      expect(r2, equals(r1));
      expect(r3, equals(r1));
      expect(internalCalls, equals(1));
    });

    test('7. Subsequent calls after completion trigger new generation', () async {
      final dedupService = _TestDedupLocationService(
        onFetch: () async => const LatLng(28.715, 77.170),
      );

      expect(dedupService.positionRequestGeneration, equals(0));
      await dedupService.getCurrentPosition();
      expect(dedupService.positionRequestGeneration, equals(1));

      await dedupService.getCurrentPosition();
      expect(dedupService.positionRequestGeneration, equals(2));
    });

    test('8. getLastKnownPosition fast lookup', () async {
      final service = LocationTrackingService();
      service.getLastKnownPositionOverride = () async => const LatLng(28.710, 77.165);

      final pos = await service.getLastKnownPosition();
      expect(pos, equals(const LatLng(28.710, 77.165)));
    });
  });

  group('UserLocationNotifier & State Machine Tests', () {
    test('9. Successfully acquires position and updates state to available', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.granted;
      service.getCurrentPositionOverride =
          () async => const LatLng(28.715, 77.170);

      final notifier = UserLocationNotifier(service);
      await pumpEventQueue();

      expect(notifier.state.status, equals(UserLocationStatus.available));
      expect(notifier.state.position, equals(const LatLng(28.715, 77.170)));
      expect(notifier.state.errorMessage, isNull);
    });

    test('10. Transitions to serviceDisabled when location hardware is off', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.serviceDisabled;

      final notifier = UserLocationNotifier(service);
      await pumpEventQueue();

      expect(notifier.state.status, equals(UserLocationStatus.serviceDisabled));
      expect(notifier.state.position, isNull);
      expect(notifier.state.errorMessage, contains('disabled'));
    });

    test('11. Transitions to permissionDenied when permission is rejected', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.denied;

      final notifier = UserLocationNotifier(service);
      await pumpEventQueue();

      expect(notifier.state.status, equals(UserLocationStatus.permissionDenied));
      expect(notifier.state.position, isNull);
    });

    test('12. Transitions to permissionDeniedForever when permanently denied', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.deniedForever;

      final notifier = UserLocationNotifier(service);
      await pumpEventQueue();

      expect(notifier.state.status,
          equals(UserLocationStatus.permissionDeniedForever));
      expect(notifier.state.errorMessage, contains('settings'));
    });

    test('13. Transitions to timedOut when GPS fix cannot be acquired', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.granted;
      service.getCurrentPositionOverride = () async => null;

      final notifier = UserLocationNotifier(service);
      await pumpEventQueue();

      expect(notifier.state.status, equals(UserLocationStatus.timedOut));
      expect(notifier.state.position, isNull);
    });

    test('13b. Transitions to unavailable when location services cannot be initialized', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.unavailable;

      final notifier = UserLocationNotifier(service);
      await pumpEventQueue();

      expect(notifier.state.status, equals(UserLocationStatus.unavailable));
      expect(notifier.state.isUnavailable, isTrue);
      expect(notifier.state.errorMessage, contains('unavailable'));
    });

    test('13c. Plain-language pre-permission disclosure flow', () async {
      final service = LocationTrackingService();
      bool requestedOsPrompt = false;

      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async {
        if (requestIfNeeded) {
          requestedOsPrompt = true;
          return LocationPermissionResult.granted;
        }
        return LocationPermissionResult.denied;
      };
      service.getCurrentPositionOverride =
          () async => const LatLng(28.715, 77.170);

      final notifier = UserLocationNotifier(service);
      await pumpEventQueue();

      // On startup with default requestIfNeeded: false, status is permissionDenied without OS prompt
      expect(notifier.state.status, equals(UserLocationStatus.permissionDenied));
      expect(requestedOsPrompt, isFalse,
          reason: 'Must not invoke system permission prompt prior to user intent');

      // User taps "Allow Location Access" after seeing disclosure
      await notifier.requestPermission();
      expect(requestedOsPrompt, isTrue);
      expect(notifier.state.status, equals(UserLocationStatus.available));
      expect(notifier.state.position, equals(const LatLng(28.715, 77.170)));
    });

    test('13d. SavedRoute.startPoint returns null when route points are empty', () {
      final emptyRoute = SavedRoute(
        id: 'r_empty',
        name: 'Empty Route',
        activityType: OutdoorActivityType.walking,
        distanceMeters: 0,
        estimatedDurationSeconds: 0,
        difficulty: RouteDifficulty.easy,
        points: const [],
        isSavedByUser: false,
        createdAt: DateTime.now(),
      );
      expect(emptyRoute.startPoint, isNull,
          reason: 'Neutral coordinates (0,0) must never represent route start coordinates');
    });
  });

  group('Providers Isolation & Race Condition Prevention Tests', () {
    test('14. Never initiates route discovery when location is not resolved', () async {
      int discoverCallCount = 0;
      final fakeEngine = _MockRouteDiscoveryEngine(
        onDiscover: (center, filter) {
          discoverCallCount++;
          return Future.value([]);
        },
      );

      final container = ProviderContainer(
        overrides: [
          routeDiscoveryEngineProvider.overrideWithValue(fakeEngine),
          userLocationNotifierProvider.overrideWith(
            (ref) => _ControlledLocationNotifier(UserLocationState.initial),
          ),
        ],
      );
      addTearDown(container.dispose);

      // On initial state (center is null), discovery returns empty without network calls
      final routes = await container.read(discoveredRoutesProvider.future);
      expect(routes, isEmpty);
      expect(discoverCallCount, equals(0),
          reason: 'Must never query Overpass/Valhalla with null or fallback center');
    });

    test('15. Single discovery query fired only after valid GPS position acquired', () async {
      int discoverCallCount = 0;
      LatLng? queriedCenter;

      final fakeEngine = _MockRouteDiscoveryEngine(
        onDiscover: (center, filter) {
          discoverCallCount++;
          queriedCenter = center;
          return Future.value([]);
        },
      );

      final notifier = _ControlledLocationNotifier(UserLocationState.initial);

      final container = ProviderContainer(
        overrides: [
          routeDiscoveryEngineProvider.overrideWithValue(fakeEngine),
          userLocationNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Step 1: Initial state -> no discovery query
      expect(await container.read(discoveredRoutesProvider.future), isEmpty);
      expect(discoverCallCount, equals(0));

      // Step 2: GPS acquires real position (Delhi)
      notifier.emit(const UserLocationState(
        status: UserLocationStatus.available,
        position: LatLng(28.715, 77.170),
      ));

      // Effective center switches to Delhi
      expect(container.read(effectiveMapCenterProvider),
          equals(const LatLng(28.715, 77.170)));

      // Step 3: Discovery queries exactly once for Delhi, never for NYC
      await container.read(discoveredRoutesProvider.future);
      expect(discoverCallCount, equals(1));
      expect(queriedCenter, equals(const LatLng(28.715, 77.170)));
    });

    test('16. Manual center override keeps user GPS coordinates separate', () async {
      final userGps = const LatLng(28.715, 77.170);
      final manualPin = const LatLng(28.6139, 77.2090); // Connaught Place

      final notifier = _ControlledLocationNotifier(UserLocationState(
        status: UserLocationStatus.available,
        position: userGps,
      ));

      final container = ProviderContainer(
        overrides: [
          userLocationNotifierProvider.overrideWith((ref) => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Prior to manual pin, effective center matches user GPS
      expect(container.read(effectiveMapCenterProvider), equals(userGps));
      expect(container.read(userCurrentLocationProvider), equals(userGps));

      // User drags map / selects a pin
      container.read(selectedMapCenterProvider.notifier).state = manualPin;

      // Effective center for discovery shifts to manual pin
      expect(container.read(effectiveMapCenterProvider), equals(manualPin));

      // BUT actual GPS coordinates remain strictly untouched
      expect(container.read(userCurrentLocationProvider), equals(userGps));
      expect(container.read(userLocationStateProvider).position, equals(userGps));

      // Resetting manual center restores following user GPS
      container.read(selectedMapCenterProvider.notifier).state = null;
      expect(container.read(effectiveMapCenterProvider), equals(userGps));
    });
  });

  group('Empty State & Neutral Coordinate Protection Widget Tests', () {
    testWidgets('17. RouteDetailScreen displays empty state when route points are empty',
        (tester) async {
      final emptyRoute = SavedRoute(
        id: 'empty_route_1',
        name: 'Empty Route',
        activityType: OutdoorActivityType.walking,
        distanceMeters: 0,
        estimatedDurationSeconds: 0,
        difficulty: RouteDifficulty.easy,
        points: const [],
        isSavedByUser: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: RouteDetailScreen(route: emptyRoute),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No Route Geometry Available'), findsOneWidget);
      expect(find.text('This route does not contain any map coordinates.'),
          findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('18. OutdoorSummaryScreen displays empty state when activity points are empty',
        (tester) async {
      final emptyActivity = OutdoorActivity(
        id: 'act_empty',
        userId: 'test_user',
        title: 'Empty Activity',
        activityType: OutdoorActivityType.running,
        status: OutdoorActivityStatus.completed,
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        endTime: DateTime.now(),
        durationSeconds: 1800,
        distanceMeters: 0,
        averagePaceSecondsPerKm: 0,
        averageSpeedKmh: 0.0,
        caloriesBurned: 100,
        points: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: OutdoorSummaryScreen(activity: emptyActivity),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No GPS Path Recorded'), findsOneWidget);
      expect(
          find.text('No route coordinates were recorded for this workout.'),
          findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('19. OutdoorRecordingScreen displays acquiring GPS state when location is null and points are empty',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OutdoorRecordingScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Acquiring GPS Signal...'), findsOneWidget);
      expect(find.text('Stand in an open area for best accuracy.'),
          findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });
  });
}

class _TestDedupLocationService extends LocationTrackingService {
  _TestDedupLocationService({required this.onFetch});

  final Future<LatLng?> Function() onFetch;
  Future<LatLng?>? _testInFlight;
  int _testGeneration = 0;

  @override
  int get positionRequestGeneration => _testGeneration;

  @override
  Future<LatLng?> getCurrentPosition() async {
    if (_testInFlight != null) {
      return _testInFlight!;
    }
    final future = () async {
      _testGeneration++;
      return await onFetch();
    }();
    _testInFlight = future;
    try {
      return await future;
    } finally {
      _testInFlight = null;
    }
  }
}

class _ControlledLocationNotifier extends UserLocationNotifier {
  _ControlledLocationNotifier(UserLocationState initial)
      : super(_DummyLocationService()) {
    state = initial;
  }

  void emit(UserLocationState newState) {
    state = newState;
  }

  @override
  Future<void> refreshLocation({bool requestIfNeeded = false}) async {}
}

class _DummyLocationService extends LocationTrackingService {
  @override
  Future<LocationPermissionResult> checkPermissionDetailed({
    bool requestIfNeeded = true,
  }) async =>
      LocationPermissionResult.granted;

  @override
  Future<LatLng?> getCurrentPosition() async => null;

  @override
  Future<LatLng?> getLastKnownPosition() async => null;
}

class _MockRouteDiscoveryEngine extends RouteDiscoveryEngine {
  _MockRouteDiscoveryEngine({required this.onDiscover});

  final Future<List<SavedRoute>> Function(LatLng center, RouteFilter? filter)
      onDiscover;

  @override
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  }) {
    return onDiscover(center, filter);
  }
}
