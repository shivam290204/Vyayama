import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/services/gps_filter_service.dart';
import 'package:fitbuddy/features/maps/domain/services/location_tracking_service.dart';
import 'package:fitbuddy/features/maps/domain/services/outdoor_session_recovery_service.dart';
import 'package:fitbuddy/features/maps/presentation/screens/outdoor_recording_screen.dart';
import 'package:fitbuddy/features/maps/presentation/widgets/outdoor_recovery_dialog.dart';
import 'package:fitbuddy/features/maps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

Position _makePosition({
  required double latitude,
  required double longitude,
  required DateTime timestamp,
  double accuracy = 5.0,
  double altitude = 15.0,
  double speed = 2.5,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: altitude,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speed,
    speedAccuracy: 0.5,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // 1. GPS Initialization & Permission Handling Tests
  // ---------------------------------------------------------------------------
  group('GPS Initialization & Permission Tests', () {
    test('1. startRecording fails when location service is disabled', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.serviceDisabled;

      final started = await service.startRecording(OutdoorActivityType.walking);

      expect(started, isFalse);
      expect(service.value.status, equals(OutdoorActivityStatus.discarded));
      expect(service.value.isInitializingGps, isFalse);
      expect(service.value.initializationError, contains('disabled'));
    });

    test('2. startRecording fails when location permission is denied', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.denied;

      final started = await service.startRecording(OutdoorActivityType.running);

      expect(started, isFalse);
      expect(service.value.isInitializingGps, isFalse);
      expect(service.value.initializationError, contains('permission is required'));
    });

    test('3. startRecording fails gracefully on GPS initial fix timeout', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.granted;
      // Simulate timeout by returning null position
      service.getCurrentPositionOverride = () async => null;

      final started = await service.startRecording(
        OutdoorActivityType.walking,
        initialFixTimeout: const Duration(milliseconds: 50),
      );

      expect(started, isFalse);
      expect(service.value.status, equals(OutdoorActivityStatus.discarded));
      expect(service.value.isInitializingGps, isFalse);
      expect(service.value.initializationError, contains('Unable to acquire GPS fix'));
    });

    test('4. startRecording succeeds when permission is granted and initial fix arrives', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.granted;
      service.getCurrentPositionOverride = () async => const LatLng(51.505, -0.090);

      final started = await service.startRecording(OutdoorActivityType.walking);

      expect(started, isTrue);
      expect(service.value.status, equals(OutdoorActivityStatus.active));
      expect(service.value.isInitializingGps, isFalse);
      expect(service.value.initializationError, isNull);
      expect(service.value.points, hasLength(1));
      expect(service.value.currentPosition, equals(const LatLng(51.505, -0.090)));
      expect(service.value.activityId, isNotNull);

      await service.stopTracking();
    });
  });

  // ---------------------------------------------------------------------------
  // 2. GpsFilterService Accuracy, Drift & Speed Rejection Tests
  // ---------------------------------------------------------------------------
  group('GpsFilterService Filtering Tests', () {
    const filter = GpsFilterService();
    final t0 = DateTime(2026, 10, 31, 10, 0, 0);

    test('5. Rejects candidate with horizontal accuracy exceeding 20m threshold', () {
      final p1 = GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: t0, accuracy: 5.0);
      final pInaccurate = GpsPoint(
        latitude: 51.506,
        longitude: -0.090,
        timestamp: t0.add(const Duration(seconds: 4)),
        accuracy: 25.0, // > 20m
      );

      expect(filter.isValidNextPoint(p1, pInaccurate), isFalse);
    });

    test('6. Rejects exact duplicate coordinates (zero displacement)', () {
      final p1 = GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: t0, accuracy: 5.0);
      final pDuplicate = GpsPoint(
        latitude: 51.505,
        longitude: -0.090,
        timestamp: t0.add(const Duration(seconds: 3)),
        accuracy: 5.0,
      );

      expect(filter.isValidNextPoint(p1, pDuplicate), isFalse);
    });

    test('7. Rejects stationary GPS jitter (< 3m displacement)', () {
      final p1 = GpsPoint(latitude: 51.505000, longitude: -0.090000, timestamp: t0, accuracy: 4.0);
      // Offset ~ 0.5m
      final pJitter = GpsPoint(
        latitude: 51.505003,
        longitude: -0.090002,
        timestamp: t0.add(const Duration(seconds: 4)),
        accuracy: 4.0,
      );

      expect(filter.isValidNextPoint(p1, pJitter), isFalse);
    });

    test('8. Accepts legitimate slow walking movement (displacement >= 3m)', () {
      final p1 = GpsPoint(latitude: 51.505000, longitude: -0.090000, timestamp: t0, accuracy: 4.0);
      // Offset ~ 4.5m in 4 seconds = ~1.1 m/s (slow walking)
      final pWalk = GpsPoint(
        latitude: 51.505040,
        longitude: -0.090000,
        timestamp: t0.add(const Duration(seconds: 4)),
        accuracy: 4.0,
      );

      expect(filter.isValidNextPoint(p1, pWalk), isTrue);
    });

    test('9. Accepts legitimate running movement (displacement >= 3m, speed ~ 3.5 m/s)', () {
      final p1 = GpsPoint(latitude: 51.505000, longitude: -0.090000, timestamp: t0, accuracy: 4.0);
      // Offset ~ 7.5m in 2 seconds = ~3.75 m/s (running)
      final pRun = GpsPoint(
        latitude: 51.505068,
        longitude: -0.090000,
        timestamp: t0.add(const Duration(seconds: 2)),
        accuracy: 4.0,
      );

      expect(filter.isValidNextPoint(p1, pRun), isTrue);
    });

    test('10. Rejects unrealistic teleportation jumps (> 45 km/h / 12.5 m/s)', () {
      final p1 = GpsPoint(latitude: 51.505000, longitude: -0.090000, timestamp: t0, accuracy: 5.0);
      // 200m away in 2 seconds = 100 m/s = 360 km/h (impossible teleport)
      final pTeleport = GpsPoint(
        latitude: 51.506800,
        longitude: -0.090000,
        timestamp: t0.add(const Duration(seconds: 2)),
        accuracy: 5.0,
      );

      expect(filter.isValidNextPoint(p1, pTeleport), isFalse);
    });

    test('11. Rejects out-of-order and distant future timestamps', () {
      final p1 = GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: t0, accuracy: 5.0);

      final pPast = GpsPoint(
        latitude: 51.5055,
        longitude: -0.090,
        timestamp: t0.subtract(const Duration(seconds: 5)),
        accuracy: 5.0,
      );
      expect(filter.isValidNextPoint(p1, pPast), isFalse);

      final pFuture = GpsPoint(
        latitude: 51.5055,
        longitude: -0.090,
        timestamp: DateTime.now().add(const Duration(hours: 1)),
        accuracy: 5.0,
      );
      expect(filter.isValidNextPoint(p1, pFuture), isFalse);
    });

    test('12. isSignalGap detects GPS outages exceeding gap threshold (120s)', () {
      final p1 = GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: t0);
      final pAfterGap = GpsPoint(
        latitude: 51.506,
        longitude: -0.090,
        timestamp: t0.add(const Duration(seconds: 150)),
      );

      expect(filter.isSignalGap(p1, pAfterGap), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Metric Calculations (Distance, Pace, Speed)
  // ---------------------------------------------------------------------------
  group('Distance, Pace, and Speed Calculations Tests', () {
    const filter = GpsFilterService();

    test('13. Calculates accurate geodesic distance between coordinates', () {
      final p1 = GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: DateTime.now());
      final p2 = GpsPoint(latitude: 51.515, longitude: -0.090, timestamp: DateTime.now());

      final d = filter.distanceBetween(p1, p2);
      expect(d, greaterThan(1100)); // ~1.11 km
      expect(d, lessThan(1125));
    });

    test('14. Safely calculates pace with zero distance, zero duration, or excessive duration', () {
      expect(filter.calculateAveragePaceSeconds(0, 100), equals(0));
      expect(filter.calculateAveragePaceSeconds(1000, 0), equals(0));
      expect(filter.calculateAveragePaceSeconds(-50, 100), equals(0));
      // 100 meters in 2 hours = 72,000 sec/km -> clamped to 0
      expect(filter.calculateAveragePaceSeconds(100, 7200), equals(0));

      // 1000 meters in 300 seconds (5 min/km)
      expect(filter.calculateAveragePaceSeconds(1000, 300), equals(300));
    });

    test('15. Safely calculates speed without division-by-zero or negative values', () {
      expect(filter.calculateAverageSpeedKmh(0, 300), equals(0.0));
      expect(filter.calculateAverageSpeedKmh(1000, 0), equals(0.0));
      expect(filter.calculateAverageSpeedKmh(-100, 300), equals(0.0));

      // 3000m in 900s (15 mins) = 3 km in 0.25 hrs = 12.0 km/h
      expect(filter.calculateAverageSpeedKmh(3000, 900), closeTo(12.0, 0.01));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Pause, Resume, and Finish Lifecycle Tests
  // ---------------------------------------------------------------------------
  group('Pause, Resume, and Finish Lifecycle Tests', () {
    test('16. Pause stops active status and prevents displacement accumulation while paused', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.granted;
      service.getCurrentPositionOverride = () async => const LatLng(51.505, -0.090);

      final controller = StreamController<Position>.broadcast();
      service.getPositionStreamOverride = (_) => controller.stream;

      await service.startRecording(OutdoorActivityType.walking);

      final t0 = DateTime.now();

      // Emit movement point while active
      controller.add(_makePosition(
        latitude: 51.50505,
        longitude: -0.090,
        timestamp: t0.add(const Duration(seconds: 4)),
      ));
      await Future<void>.delayed(Duration.zero);

      final distBeforePause = service.value.distanceMeters;
      expect(distBeforePause, greaterThan(0));

      // Pause workout
      service.pauseRecording();
      expect(service.value.status, equals(OutdoorActivityStatus.paused));

      // Emit coordinates while paused (user walked 50m while paused)
      controller.add(_makePosition(
        latitude: 51.50550,
        longitude: -0.090,
        timestamp: t0.add(const Duration(seconds: 30)),
      ));
      await Future<void>.delayed(Duration.zero);

      // Distance did NOT accumulate while paused
      expect(service.value.distanceMeters, equals(distBeforePause));

      // Resume workout
      service.resumeRecording();
      expect(service.value.status, equals(OutdoorActivityStatus.active));

      // Emit first coordinate after resume
      controller.add(_makePosition(
        latitude: 51.50555,
        longitude: -0.090,
        timestamp: t0.add(const Duration(seconds: 35)),
      ));
      await Future<void>.delayed(Duration.zero);

      // Baseline reset prevented false jump from pre-pause point
      expect(service.value.distanceMeters, equals(distBeforePause));

      await service.stopTracking();
      await controller.close();
    });

    test('17. Finish compiles completed OutdoorActivity, stops resources, and is idempotent', () async {
      final storage = const LocalOutdoorStorage();
      final repo = OutdoorActivityRepository(storage: storage);
      final service = LocationTrackingService(repository: repo);

      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.granted;
      service.getCurrentPositionOverride = () async => const LatLng(51.505, -0.090);

      await service.startRecording(OutdoorActivityType.running);

      final act1 = await service.finishRecording(title: 'Morning 5K');
      expect(act1, isNotNull);
      expect(act1!.title, equals('Morning 5K'));
      expect(act1.status, equals(OutdoorActivityStatus.completed));
      expect(service.value.status, equals(OutdoorActivityStatus.completed));

      // Second finish call returns the same saved activity without duplicate persistence
      final act2 = await service.finishRecording(title: 'Morning 5K');
      expect(act2, equals(act1));

      // Verify stored locally
      final stored = await repo.getAllActivities();
      expect(stored.where((a) => a.id == act1.id), hasLength(1));
    });

    test('18. Discard stops tracking and resets state without creating activity record', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.granted;
      service.getCurrentPositionOverride = () async => const LatLng(51.505, -0.090);

      await service.startRecording(OutdoorActivityType.walking);
      expect(service.value.status, equals(OutdoorActivityStatus.active));

      service.discardRecording();
      expect(service.value.status, equals(OutdoorActivityStatus.discarded));
      expect(service.value.points, isEmpty);
      expect(service.value.distanceMeters, equals(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Crash Recovery & Checkpoint Tests
  // ---------------------------------------------------------------------------
  group('Crash Recovery & Checkpointing Tests', () {
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('vyayama_recovery_test_');
      tempFile = File('${tempDir.path}/${OutdoorSessionRecoveryService.checkpointFileName}');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('19. Saves and retrieves valid session checkpoint from persistent storage', () async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);
      final now = DateTime.now();

      final checkpoint = OutdoorSessionCheckpoint(
        activityId: 'outdoor_test_123',
        activityType: OutdoorActivityType.hiking,
        status: OutdoorActivityStatus.active,
        startTime: now.subtract(const Duration(minutes: 10)),
        durationSeconds: 600,
        distanceMeters: 1450.0,
        points: [
          GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: now),
        ],
        lastCheckpointTime: now,
      );

      await recoveryService.saveCheckpoint(checkpoint);

      expect(tempFile.existsSync(), isTrue);

      final retrieved = await recoveryService.getActiveCheckpoint();
      expect(retrieved, isNotNull);
      expect(retrieved!.activityId, equals('outdoor_test_123'));
      expect(retrieved.activityType, equals(OutdoorActivityType.hiking));
      expect(retrieved.durationSeconds, equals(600));
      expect(retrieved.distanceMeters, equals(1450.0));
      expect(retrieved.points, hasLength(1));
    });

    test('20. Clears checkpoint on explicit clearCheckpoint', () async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);
      final checkpoint = OutdoorSessionCheckpoint(
        activityId: 'outdoor_test_456',
        activityType: OutdoorActivityType.running,
        status: OutdoorActivityStatus.active,
        startTime: DateTime.now(),
        durationSeconds: 120,
        distanceMeters: 400.0,
        points: [],
        lastCheckpointTime: DateTime.now(),
      );

      await recoveryService.saveCheckpoint(checkpoint);
      expect(await recoveryService.getActiveCheckpoint(), isNotNull);

      await recoveryService.clearCheckpoint();
      expect(await recoveryService.getActiveCheckpoint(), isNull);
      expect(tempFile.existsSync(), isFalse);
    });

    test('21. Discards corrupted or invalid checkpoint data safely (corrupt JSON and bad CRC-32)', () async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);

      // 1. Malformed JSON
      await tempFile.writeAsString('{ malformed invalid json');
      expect(await recoveryService.getActiveCheckpoint(), isNull);
      expect(tempFile.existsSync(), isFalse); // Cleaned up corrupted file

      // 2. Invalid CRC-32 checksum
      final validPayload = jsonEncode({
        'activity_id': 'bad_crc_id',
        'activity_type': 'running',
        'status': 'active',
        'start_time': DateTime.now().toIso8601String(),
        'duration_seconds': 100,
        'distance_meters': 500.0,
        'elevation_gain_meters': 0.0,
        'points': [],
        'last_checkpoint_time': DateTime.now().toIso8601String(),
      });

      final tamperedEnvelope = jsonEncode({
        'schema_version': 1,
        'crc32': 99999999, // Intentional mismatch
        'payload': validPayload,
      });

      await tempFile.writeAsString(tamperedEnvelope);
      expect(await recoveryService.getActiveCheckpoint(), isNull);
      expect(tempFile.existsSync(), isFalse); // Corrupted file safely removed
    });

    test('21b. Rejects out-of-order stale async checkpoint writes', () async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);
      final now = DateTime.now();

      final cp1 = OutdoorSessionCheckpoint(
        activityId: 'order_test_1',
        activityType: OutdoorActivityType.running,
        status: OutdoorActivityStatus.active,
        startTime: now,
        durationSeconds: 10,
        distanceMeters: 50.0,
        points: [],
        lastCheckpointTime: now,
      );

      final cp2 = OutdoorSessionCheckpoint(
        activityId: 'order_test_1',
        activityType: OutdoorActivityType.running,
        status: OutdoorActivityStatus.active,
        startTime: now,
        durationSeconds: 20,
        distanceMeters: 100.0,
        points: [],
        lastCheckpointTime: now.add(const Duration(seconds: 10)),
      );

      // Sequential writes in order
      await recoveryService.saveCheckpoint(cp1);
      await recoveryService.saveCheckpoint(cp2);

      final active = await recoveryService.getActiveCheckpoint();
      expect(active, isNotNull);
      expect(active!.durationSeconds, equals(20));
      expect(active.distanceMeters, equals(100.0));
    });

    test('21c. Migrates legacy SharedPreferences checkpoint to file-based storage seamlessly', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final legacyCheckpoint = OutdoorSessionCheckpoint(
        activityId: 'legacy_migrated_1',
        activityType: OutdoorActivityType.hiking,
        status: OutdoorActivityStatus.active,
        startTime: now.subtract(const Duration(minutes: 5)),
        durationSeconds: 300,
        distanceMeters: 800.0,
        points: [],
        lastCheckpointTime: now,
      );

      await prefs.setString(
        OutdoorSessionRecoveryService.legacyCheckpointKey,
        jsonEncode(legacyCheckpoint.toJson()),
      );

      final recoveryService = OutdoorSessionRecoveryService(
        storageFile: tempFile,
        legacyPrefs: prefs,
      );

      // Verify active checkpoint is recovered via migration
      final recovered = await recoveryService.getActiveCheckpoint();
      expect(recovered, isNotNull);
      expect(recovered!.activityId, equals('legacy_migrated_1'));
      expect(recovered.durationSeconds, equals(300));

      // Verify written to file and cleared from SharedPreferences
      expect(tempFile.existsSync(), isTrue);
      expect(prefs.containsKey(OutdoorSessionRecoveryService.legacyCheckpointKey), isFalse);
    });

    test('22. restoreSession restores in-memory state in paused mode for safe resume', () async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);
      final service = LocationTrackingService(recoveryService: recoveryService);

      final now = DateTime.now();
      final checkpoint = OutdoorSessionCheckpoint(
        activityId: 'outdoor_recovered_789',
        activityType: OutdoorActivityType.running,
        status: OutdoorActivityStatus.active,
        startTime: now.subtract(const Duration(minutes: 5)),
        durationSeconds: 300,
        distanceMeters: 1000.0,
        points: [
          GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: now),
        ],
        lastCheckpointTime: now,
      );

      await service.restoreSession(checkpoint);

      expect(service.value.status, equals(OutdoorActivityStatus.paused));
      expect(service.value.activityId, equals('outdoor_recovered_789'));
      expect(service.value.durationSeconds, equals(300));
      expect(service.value.distanceMeters, equals(1000.0));
      expect(service.value.points, hasLength(1));

      await service.stopTracking();
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Diagnostic Rate Counter & Activity Profile Settings
  // ---------------------------------------------------------------------------
  group('Diagnostic Counter & Activity Profile Settings Tests', () {
    test('23. fixesPerMinute reports fixes received in rolling 60-second window', () async {
      final service = LocationTrackingService();
      service.checkPermissionDetailedOverride =
          ({bool requestIfNeeded = true}) async =>
              LocationPermissionResult.granted;
      service.getCurrentPositionOverride = () async => const LatLng(51.505, -0.090);

      final controller = StreamController<Position>.broadcast();
      service.getPositionStreamOverride = (_) => controller.stream;

      await service.startRecording(OutdoorActivityType.walking);
      expect(service.fixesPerMinute, equals(1)); // initial fix

      final now = DateTime.now();
      controller.add(_makePosition(latitude: 51.5051, longitude: -0.090, timestamp: now));
      controller.add(_makePosition(latitude: 51.5052, longitude: -0.090, timestamp: now));
      await Future<void>.delayed(Duration.zero);

      expect(service.fixesPerMinute, equals(3));

      await service.stopTracking();
      await controller.close();
    });

    test('24. GpsFilterService.forActivity configures activity-tailored parameters', () {
      final walkFilter = GpsFilterService.forActivity(OutdoorActivityType.walking);
      expect(walkFilter.maxAllowedAccuracyMeters, equals(20.0));
      expect(walkFilter.maxRealisticSpeedMps, equals(4.5)); // ~16.2 km/h

      final runFilter = GpsFilterService.forActivity(OutdoorActivityType.running);
      expect(runFilter.maxAllowedAccuracyMeters, equals(20.0));
      expect(runFilter.maxRealisticSpeedMps, equals(8.5)); // ~30.6 km/h

      final hikeFilter = GpsFilterService.forActivity(OutdoorActivityType.hiking);
      expect(hikeFilter.maxAllowedAccuracyMeters, equals(20.0));
      expect(hikeFilter.maxRealisticSpeedMps, equals(4.5)); // ~16.2 km/h
    });

    test('24b. Walking speed boundary test accepts valid walking speeds and rejects motor vehicle speeds', () {
      final walkFilter = GpsFilterService.forActivity(OutdoorActivityType.walking);
      final t0 = DateTime(2026, 10, 31, 10, 0, 0);
      final p0 = GpsPoint(latitude: 51.500000, longitude: -0.090000, timestamp: t0, accuracy: 5.0);

      // 1. Valid brisk walking movement: 20 meters over 5.0 seconds = 4.0 m/s (~14.4 km/h) <= 4.5 m/s threshold
      // ~0.000180 degrees latitude ~= 20.0 meters
      final pBriskWalk = GpsPoint(
        latitude: 51.500180,
        longitude: -0.090000,
        timestamp: t0.add(const Duration(seconds: 5)),
        accuracy: 5.0,
      );
      expect(walkFilter.isValidNextPoint(p0, pBriskWalk), isTrue);

      // 2. Motor vehicle speed during walking session: 35 meters over 5.0 seconds = 7.0 m/s (> 4.5 m/s threshold)
      // ~0.000315 degrees latitude ~= 35.0 meters
      final pVehicleSpeed = GpsPoint(
        latitude: 51.500315,
        longitude: -0.090000,
        timestamp: t0.add(const Duration(seconds: 5)),
        accuracy: 5.0,
      );
      expect(walkFilter.isValidNextPoint(p0, pVehicleSpeed), isFalse);
    });

    test('24c. Running speed boundary test accepts fast sprints and rejects vehicular transit', () {
      final runFilter = GpsFilterService.forActivity(OutdoorActivityType.running);
      final t0 = DateTime(2026, 10, 31, 10, 0, 0);
      final p0 = GpsPoint(latitude: 51.500000, longitude: -0.090000, timestamp: t0, accuracy: 5.0);

      // 1. Fast human sprint: 38 meters over 5.0 seconds = 7.6 m/s (~27.4 km/h) <= 8.5 m/s threshold
      // ~0.000342 degrees latitude ~= 38.0 meters
      final pFastSprint = GpsPoint(
        latitude: 51.500342,
        longitude: -0.090000,
        timestamp: t0.add(const Duration(seconds: 5)),
        accuracy: 5.0,
      );
      expect(runFilter.isValidNextPoint(p0, pFastSprint), isTrue);

      // 2. Car transit or jump: 60 meters over 5.0 seconds = 12.0 m/s (~43.2 km/h) > 8.5 m/s threshold
      // ~0.000540 degrees latitude ~= 60.0 meters
      final pCarTransit = GpsPoint(
        latitude: 51.500540,
        longitude: -0.090000,
        timestamp: t0.add(const Duration(seconds: 5)),
        accuracy: 5.0,
      );
      expect(runFilter.isValidNextPoint(p0, pCarTransit), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Crash Recovery Dialog & Startup Recovery Tests
  // ---------------------------------------------------------------------------
  group('Outdoor Recovery Dialog & App Startup Tests', () {
    late Directory tempDir;
    late File tempFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('recovery_dialog_test_');
      tempFile = File('${tempDir.path}/${OutdoorSessionRecoveryService.checkpointFileName}');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    testWidgets('25. Detects active checkpoint on open and prompts user with recovery dialog, Discard cleans up',
        (tester) async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);
      final now = DateTime.now();
      final checkpoint = OutdoorSessionCheckpoint(
        activityId: 'outdoor_ui_recover',
        activityType: OutdoorActivityType.running,
        status: OutdoorActivityStatus.active,
        startTime: now.subtract(const Duration(minutes: 8)),
        durationSeconds: 480,
        distanceMeters: 1600.0,
        points: const [],
        lastCheckpointTime: now,
      );
      await recoveryService.saveCheckpoint(checkpoint);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outdoorSessionRecoveryServiceProvider.overrideWithValue(recoveryService),
          ],
          child: const MaterialApp(
            home: OutdoorRecordingScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify recovery dialog is displayed with recovered details
      expect(find.text('Unfinished Workout Detected'), findsOneWidget);
      expect(find.textContaining('1.60 km'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Save Portion'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Tap Discard and confirm
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Confirm Discard'), findsOneWidget);
      await tester.tap(find.text('Discard Permanently'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify checkpoint was discarded from persistent storage
      final remaining = await recoveryService.getActiveCheckpoint();
      expect(remaining, isNull);
    });

    testWidgets('26. App launch recovery detection enforces hasPromptedThisLaunch to avoid duplicate prompts',
        (tester) async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);
      final now = DateTime.now();
      final checkpoint = OutdoorSessionCheckpoint(
        activityId: 'launch_prompt_test',
        activityType: OutdoorActivityType.walking,
        status: OutdoorActivityStatus.active,
        startTime: now.subtract(const Duration(minutes: 5)),
        durationSeconds: 300,
        distanceMeters: 750.0,
        points: const [],
        lastCheckpointTime: now,
      );
      await recoveryService.saveCheckpoint(checkpoint);

      late BuildContext capturedContext;
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outdoorSessionRecoveryServiceProvider.overrideWithValue(recoveryService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedContext = context;
                  capturedRef = ref;
                  return const Text('Home Screen');
                },
              ),
            ),
          ),
        ),
      );

      expect(recoveryService.hasPromptedThisLaunch, isFalse);

      // First call presents prompt
      final prompt1 = OutdoorSessionRecoveryDialog.promptIfNeeded(capturedContext, capturedRef);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Unfinished Workout Detected'), findsOneWidget);
      expect(recoveryService.hasPromptedThisLaunch, isTrue);

      // Dismiss dialog
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Confirm Discard'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await prompt1;

      // Second call during same launch returns false immediately without displaying dialog
      final secondResult = await OutdoorSessionRecoveryDialog.promptIfNeeded(capturedContext, capturedRef);
      expect(secondResult, isFalse);
      expect(find.text('Unfinished Workout Detected'), findsNothing);
    });

    testWidgets('27. Recovery dialog Resume action restores session in paused state',
        (tester) async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);
      final trackingService = LocationTrackingService(recoveryService: recoveryService);

      final now = DateTime.now();
      final checkpoint = OutdoorSessionCheckpoint(
        activityId: 'resume_test_77',
        activityType: OutdoorActivityType.hiking,
        status: OutdoorActivityStatus.active,
        startTime: now.subtract(const Duration(minutes: 15)),
        durationSeconds: 900,
        distanceMeters: 2500.0,
        points: [
          GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: now),
        ],
        lastCheckpointTime: now,
      );
      await recoveryService.saveCheckpoint(checkpoint);

      var navigatedToRecord = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outdoorSessionRecoveryServiceProvider.overrideWithValue(recoveryService),
            locationTrackingServiceProvider.overrideWithValue(trackingService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => OutdoorSessionRecoveryDialog.promptIfNeeded(
                      context,
                      ref,
                      onNavigateToRecord: () {
                        navigatedToRecord = true;
                      },
                    ),
                    child: const Text('Check'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Unfinished Workout Detected'), findsOneWidget);

      // Tap Resume
      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Session restored into memory in PAUSED state (clock not running, GPS not recording)
      expect(trackingService.value.status, equals(OutdoorActivityStatus.paused));
      expect(trackingService.value.activityId, equals('resume_test_77'));
      expect(trackingService.value.durationSeconds, equals(900));
      expect(trackingService.value.distanceMeters, equals(2500.0));
      expect(trackingService.value.points, hasLength(1));
      expect(navigatedToRecord, isTrue);

      await trackingService.stopTracking();
    });

    testWidgets('28. Recovery dialog Save Portion action saves to repository and clears checkpoint',
        (tester) async {
      final recoveryService = OutdoorSessionRecoveryService(storageFile: tempFile);
      final storage = const LocalOutdoorStorage();
      final repo = OutdoorActivityRepository(storage: storage);

      final now = DateTime.now();
      final checkpoint = OutdoorSessionCheckpoint(
        activityId: 'save_portion_88',
        activityType: OutdoorActivityType.walking,
        status: OutdoorActivityStatus.active,
        startTime: now.subtract(const Duration(minutes: 20)),
        durationSeconds: 1200,
        distanceMeters: 1800.0,
        points: [
          GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: now),
        ],
        lastCheckpointTime: now,
      );
      await recoveryService.saveCheckpoint(checkpoint);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outdoorSessionRecoveryServiceProvider.overrideWithValue(recoveryService),
            outdoorActivityRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () => OutdoorSessionRecoveryDialog.promptIfNeeded(context, ref),
                    child: const Text('Check'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Unfinished Workout Detected'), findsOneWidget);

      // Tap Save Portion
      await tester.tap(find.text('Save Portion'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify checkpoint cleared from disk
      final activeCheckpoint = await recoveryService.getActiveCheckpoint();
      expect(activeCheckpoint, isNull);

      // Verify activity was saved to OutdoorActivityRepository
      final savedActivities = await repo.getAllActivities();
      expect(savedActivities.where((a) => a.id == 'save_portion_88'), hasLength(1));
      final saved = savedActivities.firstWhere((a) => a.id == 'save_portion_88');
      expect(saved.distanceMeters, equals(1800.0));
      expect(saved.durationSeconds, equals(1200));
      expect(saved.status, equals(OutdoorActivityStatus.completed));
    });
  });
}
