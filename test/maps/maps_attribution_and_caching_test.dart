import 'dart:io';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/data/repositories/saved_routes_repository.dart';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    });
  });

  group('Maps Tile Caching and Attribution Tests', () {
    test('1. flutter_map NetworkTileProvider utilizes BuiltInMapCachingProvider fallback', () {
      final provider = NetworkTileProvider();
      // cachingProvider defaults to null on NetworkTileProvider, which directs
      // NetworkTileImageProvider to lazily resolve BuiltInMapCachingProvider.getOrCreateInstance()
      expect(provider.cachingProvider, isNull);
      expect(provider.supportsCancelLoading, isTrue);
    });

    test('2. BuiltInMapCachingProvider initializes and configures disk cache', () {
      final cacheProvider = BuiltInMapCachingProvider.getOrCreateInstance();
      expect(cacheProvider, isNotNull);
      expect(cacheProvider.isSupported, isTrue);
    });
  });

  group('OutdoorActivityRepository & Sync Retry Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('3. OutdoorActivity defaults to isSynced: false and saves locally', () async {
      const storage = LocalOutdoorStorage();
      final repo = OutdoorActivityRepository(storage: storage);

      final now = DateTime.now();
      final act = OutdoorActivity(
        id: 'test_sync_act_1',
        userId: 'local_user',
        activityType: OutdoorActivityType.running,
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now,
        durationSeconds: 1800,
        distanceMeters: 5000,
        averagePaceSecondsPerKm: 360,
        averageSpeedKmh: 10.0,
        points: [
          GpsPoint(latitude: 37.7749, longitude: -122.4194, altitude: 10, accuracy: 5, speed: 2.8, timestamp: now),
        ],
        isSynced: false,
      );

      await repo.saveActivity(act);

      final loaded = await repo.getActivityById('test_sync_act_1');
      expect(loaded, isNotNull);
      expect(loaded!.isSynced, isFalse);
      expect(loaded.userId, equals('local_user'));

      // In offline / unauthenticated state, syncPendingActivities returns 0 safely without throwing
      final syncedCount = await repo.syncPendingActivities();
      expect(syncedCount, equals(0));
    });

    test('4. SavedRoutesRepository handles offline routes and deferred sync safely', () async {
      const storage = LocalOutdoorStorage();
      final repo = SavedRoutesRepository(storage: storage);

      const route = SavedRoute(
        id: 'test_sync_route_1',
        name: 'Community Trail',
        activityType: OutdoorActivityType.walking,
        distanceMeters: 2500,
        estimatedDurationSeconds: 1800,
        difficulty: RouteDifficulty.easy,
        points: [],
      );

      await repo.saveRoute(route);

      final loaded = await repo.getSavedRoutes();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('test_sync_route_1'));

      final syncedCount = await repo.syncPendingRoutes();
      expect(syncedCount, equals(0));
    });
  });
}
