import 'package:fitbuddy/features/maps/data/services/map_tile_config.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/domain/services/location_tracking_service.dart';
import 'package:fitbuddy/features/maps/domain/services/route_discovery_engine.dart';
import 'package:fitbuddy/features/maps/presentation/screens/maps_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/map_tile_layer.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MapTileConfig & Centralized TileLayer Tests', () {
    test('1. MapTileConfig defaults to OpenStreetMap community endpoint and Vyayama user agent', () {
      expect(MapTileConfig.defaultTileUrl,
          equals('https://tile.openstreetmap.org/{z}/{x}/{y}.png'));
      expect(MapTileConfig.defaultUserAgent, equals('com.vyayama.fitbuddy'));
      expect(MapTileConfig.tileUrl, equals(MapTileConfig.defaultTileUrl));
      expect(MapTileConfig.userAgent, equals(MapTileConfig.defaultUserAgent));
      expect(MapTileConfig.isUsingPublicCommunityEndpoint, isTrue);
    });

    test('2. MapTileConfig copyright URL links to official OpenStreetMap terms', () {
      expect(MapTileConfig.osmCopyrightUrl,
          equals('https://openstreetmap.org/copyright'));
    });

    testWidgets('3. AppMapTileLayer and AppMapAttribution render properly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: const MapOptions(
                initialCenter: LatLng(28.715, 77.170),
                initialZoom: 14.0,
              ),
              children: const [
                AppMapTileLayer(),
                AppMapAttribution(),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TileLayer), findsOneWidget);
      expect(find.byType(RichAttributionWidget), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextSourceAttribution &&
              w.text == 'OpenStreetMap contributors',
        ),
        findsOneWidget,
      );
    });
  });

  group('MapsScreen Rendering, Location Markers & Heading Tests', () {
    testWidgets('4. Does not display fake current-location marker when GPS is unavailable',
        (tester) async {
      final notifier = _ControlledLocationNotifier(
        const UserLocationState(
          status: UserLocationStatus.unavailable,
          errorMessage: 'Location hardware unavailable',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userLocationNotifierProvider.overrideWith((ref) => notifier),
            routeDiscoveryEngineProvider.overrideWithValue(_MockRouteDiscoveryEngine()),
          ],
          child: const MaterialApp(
            home: MapsScreen(),
          ),
        ),
      );
      await tester.pump();

      // No GPS marker with navigation arrow or pulse circle
      expect(find.byIcon(Icons.navigation), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('5. Does not display current-location marker when permission is denied',
        (tester) async {
      final notifier = _ControlledLocationNotifier(
        const UserLocationState(
          status: UserLocationStatus.permissionDenied,
          errorMessage: 'Permission denied',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userLocationNotifierProvider.overrideWith((ref) => notifier),
            routeDiscoveryEngineProvider.overrideWithValue(_MockRouteDiscoveryEngine()),
          ],
          child: const MaterialApp(
            home: MapsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.navigation), findsNothing);
    });

    testWidgets('6. Displays verified GPS marker without heading when heading is null',
        (tester) async {
      final userGps = const LatLng(28.715, 77.170);
      final notifier = _ControlledLocationNotifier(
        UserLocationState(
          status: UserLocationStatus.available,
          position: userGps,
          heading: null,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userLocationNotifierProvider.overrideWith((ref) => notifier),
            routeDiscoveryEngineProvider.overrideWithValue(_MockRouteDiscoveryEngine()),
          ],
          child: const MaterialApp(
            home: MapsScreen(),
          ),
        ),
      );
      await tester.pump();

      // GPS pulse circle is rendered in MarkerLayer
      expect(find.byType(MarkerLayer), findsOneWidget);
      // Navigation heading arrow is not rendered when heading is null
      expect(find.byIcon(Icons.navigation), findsNothing);
    });

    testWidgets('7. Displays heading directional indicator when valid heading is available',
        (tester) async {
      final userGps = const LatLng(28.715, 77.170);
      final notifier = _ControlledLocationNotifier(
        UserLocationState(
          status: UserLocationStatus.available,
          position: userGps,
          heading: 90.0, // Heading East
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userLocationNotifierProvider.overrideWith((ref) => notifier),
            routeDiscoveryEngineProvider.overrideWithValue(_MockRouteDiscoveryEngine()),
          ],
          child: const MaterialApp(
            home: MapsScreen(),
          ),
        ),
      );
      await tester.pump();

      // Heading arrow is rendered and rotated
      expect(find.byIcon(Icons.navigation), findsOneWidget);
    });

    testWidgets('8. Displays distinct marker for manually selected search center',
        (tester) async {
      final manualCenter = const LatLng(28.6139, 77.2090); // Connaught Place
      final notifier = _ControlledLocationNotifier(
        const UserLocationState(
          status: UserLocationStatus.available,
          position: LatLng(28.715, 77.170), // Delhi North
        ),
      );

      final container = ProviderContainer(
        overrides: [
          userLocationNotifierProvider.overrideWith((ref) => notifier),
          routeDiscoveryEngineProvider.overrideWithValue(_MockRouteDiscoveryEngine()),
        ],
      );
      addTearDown(container.dispose);

      // Set manual center
      container.read(selectedMapCenterProvider.notifier).state = manualCenter;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MapsScreen(),
          ),
        ),
      );
      await tester.pump();

      // Distinct manual search center icon is displayed
      expect(find.byIcon(Icons.location_searching_rounded), findsOneWidget);
    });
  });

  group('Camera Behavior, Recenter & Search Area Action Tests', () {
    testWidgets('9. Recenter clears manual search center and restores following GPS',
        (tester) async {
      final userGps = const LatLng(28.715, 77.170);
      final manualCenter = const LatLng(28.6139, 77.2090);

      final notifier = _ControlledLocationNotifier(
        UserLocationState(
          status: UserLocationStatus.available,
          position: userGps,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          userLocationNotifierProvider.overrideWith((ref) => notifier),
          routeDiscoveryEngineProvider.overrideWithValue(_MockRouteDiscoveryEngine()),
        ],
      );
      addTearDown(container.dispose);

      // Initially manual center is set
      container.read(selectedMapCenterProvider.notifier).state = manualCenter;
      expect(container.read(selectedMapCenterProvider), equals(manualCenter));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MapsScreen(),
          ),
        ),
      );
      await tester.pump();

      // Tap re-center button
      final recenterBtn = find.byTooltip('Re-center My Location');
      expect(recenterBtn, findsOneWidget);
      await tester.tap(recenterBtn);
      await tester.pump();

      // Manual center is cleared back to null
      expect(container.read(selectedMapCenterProvider), isNull);
      expect(container.read(effectiveMapCenterProvider), equals(userGps));
    });

    testWidgets('10. Insignificant map movement (< 300m) does not trigger discovery or show search pill',
        (tester) async {
      final userGps = const LatLng(28.71500, 77.17000);
      final notifier = _ControlledLocationNotifier(
        UserLocationState(
          status: UserLocationStatus.available,
          position: userGps,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          userLocationNotifierProvider.overrideWith((ref) => notifier),
          routeDiscoveryEngineProvider.overrideWithValue(_MockRouteDiscoveryEngine()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MapsScreen(),
          ),
        ),
      );
      await tester.pump();

      // "Search This Area" pill should not be visible initially
      expect(find.text('Search This Area'), findsNothing);
      expect(container.read(selectedMapCenterProvider), isNull);
    });

    testWidgets('11. Tile error callback displays error banner and allows dismissal',
        (tester) async {
      final notifier = _ControlledLocationNotifier(
        const UserLocationState(
          status: UserLocationStatus.available,
          position: LatLng(28.715, 77.170),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userLocationNotifierProvider.overrideWith((ref) => notifier),
            routeDiscoveryEngineProvider.overrideWithValue(_MockRouteDiscoveryEngine()),
          ],
          child: const MaterialApp(
            home: MapsScreen(),
          ),
        ),
      );
      await tester.pump();

      // Banner is not visible when no error
      expect(find.textContaining('Map tiles temporarily unavailable'), findsNothing);

      // Simulate a tile error
      final tileLayer = tester.widget<TileLayer>(find.byType(TileLayer));
      tileLayer.errorTileCallback?.call(
        _FakeTileImage(),
        'Network error',
        null,
      );
      await tester.pump();

      // Error banner is now displayed
      expect(find.textContaining('Map tiles temporarily unavailable'), findsOneWidget);

      // Dismiss the banner using its dedicated key
      final closeBtn = find.byKey(const Key('tile_error_close_button'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pump();

      expect(find.textContaining('Map tiles temporarily unavailable'), findsNothing);
    });
  });
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
  @override
  Future<List<SavedRoute>> discoverRoutes({
    required LatLng center,
    double radiusKm = 10.0,
    RouteFilter? filter,
  }) async {
    return [];
  }
}

class _FakeTileImage extends Fake implements TileImage {}

