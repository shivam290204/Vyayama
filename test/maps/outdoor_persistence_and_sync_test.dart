import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/data/repositories/saved_routes_repository.dart';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_tombstone.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/services/connectivity_monitor.dart';
import 'package:fitbuddy/features/maps/domain/services/outdoor_sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  OutdoorActivity makeSampleActivity({
    required String id,
    String userId = 'user_123',
    DateTime? startTime,
    bool isSynced = false,
  }) {
    final start = startTime ?? DateTime(2026, 10, 31, 10, 0, 0);
    return OutdoorActivity(
      id: id,
      userId: userId,
      activityType: OutdoorActivityType.running,
      startTime: start,
      endTime: start.add(const Duration(minutes: 30)),
      durationSeconds: 1800,
      distanceMeters: 5000.0,
      averagePaceSecondsPerKm: 360,
      averageSpeedKmh: 10.0,
      points: [
        GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: start),
        GpsPoint(latitude: 51.508, longitude: -0.090, timestamp: start.add(const Duration(minutes: 30))),
      ],
      elevationGainMeters: 45.0,
      caloriesBurned: 350,
      status: OutdoorActivityStatus.completed,
      isSynced: isSynced,
      title: 'Morning 5K',
    );
  }

  SavedRoute makeSampleRoute({
    required String id,
    String userId = 'user_123',
    RouteSurface surface = RouteSurface.unknown,
    RouteElevation elevation = RouteElevation.unknown,
    double? elevationGain,
  }) {
    final now = DateTime(2026, 10, 31, 9, 0, 0);
    return SavedRoute(
      id: id,
      name: 'Thames Path Loop',
      activityType: OutdoorActivityType.walking,
      distanceMeters: 3200.0,
      estimatedDurationSeconds: 2400,
      difficulty: RouteDifficulty.easy,
      points: [
        GpsPoint(latitude: 51.505, longitude: -0.090, timestamp: now),
        GpsPoint(latitude: 51.510, longitude: -0.090, timestamp: now),
      ],
      elevationGainMeters: elevationGain,
      surfaceType: surface,
      elevationProfile: elevation,
      description: 'Scenic river walk',
      isSavedByUser: true,
      userId: userId,
      createdAt: now,
      isLoop: true,
      isDifficultyEstimated: false,
    );
  }

  // ===========================================================================
  // 1. LOCAL PERSISTENCE & RESTART SURVIVAL
  // ===========================================================================
  group('1. Local-First Persistence & Restart Survival', () {
    test('1. Saves completed workout locally with offline availability', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      final act = makeSampleActivity(id: 'act_1');
      await repo.saveActivity(act);

      final activities = await repo.getAllActivities(userId: 'user_123');
      expect(activities, hasLength(1));
      expect(activities.first.id, equals('act_1'));
      expect(activities.first.distanceMeters, equals(5000.0));
      expect(activities.first.isSynced, isFalse);
    });

    test('2. Stored activities survive simulated application restart', () async {
      // First session
      final storageSession1 = LocalOutdoorStorage(preferences: prefs);
      final repo1 = OutdoorActivityRepository(storage: storageSession1);
      final t1 = DateTime(2026, 10, 31, 8, 0);
      final t2 = DateTime(2026, 10, 31, 14, 0);

      await repo1.saveActivity(makeSampleActivity(id: 'act_early', startTime: t1));
      await repo1.saveActivity(makeSampleActivity(id: 'act_late', startTime: t2));

      // Simulate app restart by instantiating fresh storage reading the same disk
      final storageSession2 = LocalOutdoorStorage(preferences: prefs);
      final repo2 = OutdoorActivityRepository(storage: storageSession2);

      final recovered = await repo2.getAllActivities(userId: 'user_123');
      expect(recovered, hasLength(2));
      // Verifies descending sort by start_time
      expect(recovered[0].id, equals('act_late'));
      expect(recovered[1].id, equals('act_early'));
    });

    test('3. Retrieves activity by unique ID', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      await repo.saveActivity(makeSampleActivity(id: 'act_find_me'));

      final found = await repo.getActivityById('act_find_me');
      expect(found, isNotNull);
      expect(found!.title, equals('Morning 5K'));

      final missing = await repo.getActivityById('non_existent');
      expect(missing, isNull);
    });
  });

  // ===========================================================================
  // 2. RELIABLE SUPABASE SYNCHRONIZATION
  // ===========================================================================
  group('2. Reliable Supabase Synchronization & Bounded Backoff', () {
    test('4. Successful online upsert updates isSynced to true and sets user_id', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      Map<String, dynamic>? capturedPayload;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        expect(table, equals('outdoor_activities'));
        capturedPayload = payload;
      };

      final act = makeSampleActivity(id: 'act_sync_test');
      await repo.saveActivity(act);

      expect(capturedPayload, isNotNull);
      expect(capturedPayload!['id'], equals('act_sync_test'));
      expect(capturedPayload!['user_id'], equals('user_123'));
      expect(capturedPayload!['duration_seconds'], equals(1800));

      final stored = await repo.getActivityById('act_sync_test');
      expect(stored!.isSynced, isTrue);
      expect(stored.userId, equals('user_123'));
    });

    test('5. Network failure during save preserves local data with isSynced=false', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        throw Exception('Simulated network timeout');
      };

      final act = makeSampleActivity(id: 'act_fail_test');
      await repo.saveActivity(act);

      // Local activity survives intact and is marked pending sync
      final stored = await repo.getActivityById('act_fail_test');
      expect(stored, isNotNull);
      expect(stored!.isSynced, isFalse);
    });

    test('6. syncPendingActivities retries all unsynced activities idempotently', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      // Save 3 activities offline
      await storage.saveActivity(makeSampleActivity(id: 'act_offline_1', isSynced: false));
      await storage.saveActivity(makeSampleActivity(id: 'act_offline_2', isSynced: false));
      await storage.saveActivity(makeSampleActivity(id: 'act_already_synced', isSynced: true));

      final upsertedIds = <String>[];
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        upsertedIds.add(payload['id'] as String);
      };

      final count = await repo.syncPendingActivities();

      expect(count, equals(2));
      expect(upsertedIds, containsAll(['act_offline_1', 'act_offline_2']));
      expect(upsertedIds.contains('act_already_synced'), isFalse);

      final allNow = await repo.getAllActivities(userId: 'user_123');
      expect(allNow.every((a) => a.isSynced), isTrue);

      // Second sync execution is idempotent and pushes 0 duplicate records
      final secondCount = await repo.syncPendingActivities();
      expect(secondCount, equals(0));
    });

    test('7. In-flight sync mutex prevents duplicate concurrent executions', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_concurrent'));

      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      };

      // Trigger two syncs in parallel
      final future1 = repo.syncPendingActivities();
      final future2 = repo.syncPendingActivities();

      final results = await Future.wait([future1, future2]);
      // One sync executed (synced 1), the concurrent duplicate joined/returned 0
      expect(results, contains(1));
      expect(results, contains(0));
    });
  });

  // ===========================================================================
  // 3. OFFLINE DELETION & TOMBSTONE QUEUE
  // ===========================================================================
  group('3. Offline Deletion, Tombstone Queue & Resurrection Prevention', () {
    test('8. Offline deletion immediately purges local record and persists tombstone', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_delete_offline'));

      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteDeleteOverride = (table, id, userId) async {
        throw Exception('Offline: cannot reach server');
      };

      await repo.deleteActivity('act_delete_offline');

      // Local record deleted immediately
      final local = await repo.getActivityById('act_delete_offline');
      expect(local, isNull);

      // Tombstone is recorded in persistent queue
      final tombstones = await storage.getActivityTombstones();
      expect(tombstones, contains('act_delete_offline'));
      expect(await storage.isActivityTombstoned('act_delete_offline'), isTrue);
    });

    test('8b. Crash safety: tombstone recorded before local deletion immediately hides record', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      // Save activity
      await storage.saveActivity(makeSampleActivity(id: 'act_crash_step1'));

      // Simulate crash right after step 1 (tombstone written to disk) but BEFORE step 2 (deleteActivity called)
      final tombstone = OutdoorTombstone(
        id: 'act_crash_step1',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
      );
      await storage.recordTombstone(tombstone);

      // Even though raw activity entry still exists on disk, query filters it out!
      final visibleList = await repo.getAllActivities(userId: 'user_123');
      expect(visibleList.any((a) => a.id == 'act_crash_step1'), isFalse);
      expect(await repo.getActivityById('act_crash_step1'), isNull);

      // When sync runs upon recovery, it cleans up the pending tombstone and remote record
      final deletedRemoteIds = <String>[];
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteDeleteOverride = (table, id, userId) async {
        deletedRemoteIds.add(id);
      };

      await repo.syncPendingActivities();
      expect(deletedRemoteIds, contains('act_crash_step1'));
      expect(await storage.isActivityTombstoned('act_crash_step1'), isFalse);
    });

    test('8c. Crash safety: crash after local unlinking retries remote deletion on reconnect', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_crash_step2'));

      // Step 1: Tombstone recorded
      await storage.recordTombstone(OutdoorTombstone(
        id: 'act_crash_step2',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
      ));
      // Step 2: Local deletion succeeded
      await storage.deleteActivity('act_crash_step2');

      // Step 3: Remote deletion fails (e.g. offline, crash before remote call finishes)
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteDeleteOverride = (table, id, userId) async {
        throw Exception('Network lost');
      };

      // Simulating reboot: new repository instance on same storage
      final storageReboot = LocalOutdoorStorage(preferences: prefs);
      final repoReboot = OutdoorActivityRepository(storage: storageReboot);

      expect(await storageReboot.isActivityTombstoned('act_crash_step2'), isTrue);
      expect(await repoReboot.getActivityById('act_crash_step2'), isNull);

      // When connectivity is restored, sync retries and succeeds
      final remoteDeletes = <String>[];
      repoReboot.currentUserIdOverride = () => 'user_123';
      repoReboot.remoteDeleteOverride = (table, id, userId) async {
        remoteDeletes.add(id);
      };

      await repoReboot.syncPendingActivities();
      expect(remoteDeletes, contains('act_crash_step2'));
      expect(await storageReboot.isActivityTombstoned('act_crash_step2'), isFalse);
    });

    test('8d. Crash safety: crash after remote deletion before tombstone cleanup is idempotent', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      // Suppose remote delete completed on server, but client crashed before tombstone was purged
      await storage.recordTombstone(OutdoorTombstone(
        id: 'act_crash_step3',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
      ));

      // On next sync cycle, remote delete is called again (idempotent HTTP 204 in PostgreSQL)
      var remoteDeleteCallCount = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteDeleteOverride = (table, id, userId) async {
        remoteDeleteCallCount++;
        // Idempotent: success even if already deleted remotely
      };

      await repo.syncPendingActivities();
      expect(remoteDeleteCallCount, equals(1));
      // Tombstone is successfully cleaned up
      expect(await storage.isActivityTombstoned('act_crash_step3'), isFalse);
    });

    test('9. Tombstones survive simulated restart and retry on reconnect', () async {
      final storage1 = LocalOutdoorStorage(preferences: prefs);
      await storage1.recordTombstone(OutdoorTombstone(
        id: 'act_pending_del',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
      ));

      // Restart
      final storage2 = LocalOutdoorStorage(preferences: prefs);
      final repo2 = OutdoorActivityRepository(storage: storage2);

      expect(await storage2.isActivityTombstoned('act_pending_del'), isTrue);

      final deletedRemoteIds = <String>[];
      repo2.currentUserIdOverride = () => 'user_123';
      repo2.remoteDeleteOverride = (table, id, userId) async {
        deletedRemoteIds.add(id);
      };

      // When sync runs, it processes tombstones first
      await repo2.syncPendingActivities();

      expect(deletedRemoteIds, contains('act_pending_del'));
      // Tombstone removed upon successful remote execution
      expect(await storage2.isActivityTombstoned('act_pending_del'), isFalse);
    });

    test('10. Tombstone queue prevents resurrection of deleted activities', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      // Record tombstone for activity
      await storage.recordTombstone(OutdoorTombstone(
        id: 'act_tombstoned_99',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
      ));

      // Attempt to save or restore a stale copy of this activity
      await repo.saveActivity(makeSampleActivity(id: 'act_tombstoned_99'));

      // Save was dropped; activity was not resurrected
      final stored = await repo.getActivityById('act_tombstoned_99');
      expect(stored, isNull);
    });
  });

  // ===========================================================================
  // 4. SAVED ROUTES SCHEMA COMPATIBILITY & CONSTRAINTS
  // ===========================================================================
  group('4. Saved Routes Schema Compatibility & Sanitization', () {
    test('11. toSupabasePayload preserves unknown surface and elevation semantics', () {
      final route = makeSampleRoute(
        id: 'route_check_constraints',
        surface: RouteSurface.unknown,
        elevation: RouteElevation.unknown,
        elevationGain: null,
      );

      final payload = SavedRoutesRepository.toSupabasePayload(route, 'user_123');

      // Preserves actual unknown semantics ('unknown') rather than silently falsifying to 'paved'/'flat'
      expect(payload['surface_type'], equals('unknown'));
      expect(payload['elevation_profile'], equals('unknown'));

      // Non-null constraint on elevation_gain_meters defaults to 0.0
      expect(payload['elevation_gain_meters'], equals(0.0));

      // Client-only metadata omitted to prevent PostgreSQL column mismatches before migration 020
      expect(payload.containsKey('is_loop'), isFalse);
      expect(payload.containsKey('is_difficulty_estimated'), isFalse);
    });

    test('11b. SavedRoute round-trip JSON serialization preserves unknown metadata', () {
      final route = makeSampleRoute(
        id: 'route_unknown_roundtrip',
        surface: RouteSurface.unknown,
        elevation: RouteElevation.unknown,
      );
      final json = route.toJson();
      final restored = SavedRoute.fromJson(json);
      expect(restored.surfaceType, equals(RouteSurface.unknown));
      expect(restored.elevationProfile, equals(RouteElevation.unknown));
      expect(restored.isLoop, isTrue);
      expect(restored.isDifficultyEstimated, isFalse);
    });

    test('12. Saves route locally and syncs to Supabase', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = SavedRoutesRepository(storage: storage);

      Map<String, dynamic>? remotePayload;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        expect(table, equals('saved_routes'));
        remotePayload = payload;
      };

      final route = makeSampleRoute(
        id: 'route_1',
        surface: RouteSurface.trail,
        elevation: RouteElevation.hilly,
        elevationGain: 120.0,
      );

      await repo.saveRoute(route);

      expect(remotePayload, isNotNull);
      expect(remotePayload!['surface_type'], equals('trail'));
      expect(remotePayload!['elevation_profile'], equals('hilly'));
      expect(remotePayload!['elevation_gain_meters'], equals(120.0));

      final localRoutes = await repo.getSavedRoutes(userId: 'user_123');
      expect(localRoutes, hasLength(1));
      expect(localRoutes.first.name, equals('Thames Path Loop'));
    });

    test('13. Route offline deletion creates route tombstone and retries on sync', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = SavedRoutesRepository(storage: storage);

      await storage.saveRoute(makeSampleRoute(id: 'route_del_test'));

      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteDeleteOverride = (table, id, userId) async {
        throw Exception('Offline');
      };

      await repo.deleteRoute('route_del_test');

      expect((await repo.getSavedRoutes(userId: 'user_123')), isEmpty);
      expect(await storage.isRouteTombstoned('route_del_test'), isTrue);

      // Reconnect
      final deletedRemoteRouteIds = <String>[];
      repo.remoteDeleteOverride = (table, id, userId) async {
        deletedRemoteRouteIds.add(id);
      };

      await repo.syncPendingRoutes();
      expect(deletedRemoteRouteIds, contains('route_del_test'));
      expect(await storage.isRouteTombstoned('route_del_test'), isFalse);
    });
  });

  // ===========================================================================
  // 5. ACCOUNT ISOLATION & USER DATA PROTECTION
  // ===========================================================================
  group('5. Account & User Isolation Tests', () {
    test('14. User B cannot see User A activities on shared local storage', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      // User A records an activity
      await storage.saveActivity(makeSampleActivity(id: 'act_user_a', userId: 'user_a'));

      // User B queries activities
      final userBActivities = await repo.getAllActivities(userId: 'user_b');
      expect(userBActivities, isEmpty, reason: 'User B must not see User A records');

      // User A queries activities
      final userAActivities = await repo.getAllActivities(userId: 'user_a');
      expect(userAActivities, hasLength(1));
      expect(userAActivities.first.id, equals('act_user_a'));
    });

    test('15. Syncing while authenticated as User B never uploads User A activities', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      // User A activity in local storage marked unsynced
      await storage.saveActivity(makeSampleActivity(id: 'act_user_a', userId: 'user_a', isSynced: false));

      final syncedPayloads = <Map<String, dynamic>>[];
      repo.currentUserIdOverride = () => 'user_b';
      repo.remoteUpsertOverride = (table, payload) async {
        syncedPayloads.add(payload);
      };

      final syncedCount = await repo.syncPendingActivities();

      expect(syncedCount, equals(0));
      expect(syncedPayloads, isEmpty, reason: 'Must not sync User A activity under User B account');
    });

    test('16. adoptGuestData attaches guest workouts to newly authenticated user', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);

      // Unauthenticated guest workout
      await storage.saveActivity(makeSampleActivity(id: 'guest_act', userId: 'local_user', isSynced: false));
      await storage.saveRoute(makeSampleRoute(id: 'guest_route', userId: 'local_user'));

      // User registers/logs in as 'new_user_888'
      await storage.adoptGuestData('new_user_888');

      final userActs = await storage.getAllActivities(userId: 'new_user_888');
      expect(userActs, hasLength(1));
      expect(userActs.first.userId, equals('new_user_888'));
      expect(userActs.first.isSynced, isFalse);

      final userRoutes = await storage.getSavedRoutes(userId: 'new_user_888');
      expect(userRoutes, hasLength(1));
      expect(userRoutes.first.userId, equals('new_user_888'));
    });

    test('17. clearUserData purges target user data on account deletion', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);

      await storage.saveActivity(makeSampleActivity(id: 'act_keep', userId: 'user_keep'));
      await storage.saveActivity(makeSampleActivity(id: 'act_delete', userId: 'user_delete'));

      await storage.clearUserData('user_delete');

      final remaining = await storage.getAllActivities();
      expect(remaining, hasLength(1));
      expect(remaining.first.id, equals('act_keep'));
    });
  });

  // ===========================================================================
  // 6. OUTDOOR SYNC COORDINATOR & CONNECTIVITY RESTORATION
  // ===========================================================================
  group('6. OutdoorSyncCoordinator Orchestration & Connectivity Restoration', () {
    test('18. Coordinates both activities and routes sync in a single call', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final actRepo = OutdoorActivityRepository(storage: storage);
      final routesRepo = SavedRoutesRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_coord', isSynced: false));
      await storage.saveRoute(makeSampleRoute(id: 'route_coord'));

      actRepo.currentUserIdOverride = () => 'user_123';
      actRepo.remoteUpsertOverride = (table, payload) async {};

      routesRepo.currentUserIdOverride = () => 'user_123';
      routesRepo.remoteUpsertOverride = (table, payload) async {};

      final coordinator = OutdoorSyncCoordinator(
        activityRepository: actRepo,
        routesRepository: routesRepo,
      );

      final result = await coordinator.syncAll(trigger: 'startup');

      expect(result.isSuccess, isTrue);
      expect(result.activitiesSynced, equals(1));
      expect(result.routesSynced, equals(1));
      expect(result.isAlreadyRunning, isFalse);
    });

    test('19. ConnectivityMonitor debounces rapid network status transitions', () async {
      final monitor = ConnectivityMonitor(
        debounceDuration: const Duration(milliseconds: 50),
      );

      final events = <bool>[];
      final sub = monitor.onConnectivityRestored.listen((event) {
        events.add(event);
      });

      // Rapid flapping: offline -> online -> offline -> online
      monitor.notifyConnectivityChange(false);
      monitor.notifyConnectivityChange(true);
      monitor.notifyConnectivityChange(false);
      monitor.notifyConnectivityChange(true);

      // Wait for debounce timer
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events, equals([true]), reason: 'Debounce should produce only one restored event');
      await sub.cancel();
      monitor.dispose();
    });

    test('20. ConnectivityMonitor probe suppresses restored event if server is unreachable', () async {
      var probeCalls = 0;
      final monitor = ConnectivityMonitor(
        debounceDuration: const Duration(milliseconds: 20),
        reachabilityProbe: () async {
          probeCalls++;
          return false; // Reachability probe fails (e.g. captive portal or Supabase offline)
        },
      );

      final events = <bool>[];
      final sub = monitor.onConnectivityRestored.listen((event) {
        events.add(event);
      });

      // Transition from offline to online
      monitor.notifyConnectivityChange(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      monitor.notifyConnectivityChange(true);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(probeCalls, equals(1));
      expect(events, isEmpty, reason: 'Failed reachability probe must suppress connectivity restored event');

      await sub.cancel();
      monitor.dispose();
    });

    test('21. Connectivity restoration automatically triggers coordinator sync', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final actRepo = OutdoorActivityRepository(storage: storage);
      final routesRepo = SavedRoutesRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_reconnect', isSynced: false));

      var syncedCount = 0;
      actRepo.currentUserIdOverride = () => 'user_123';
      actRepo.remoteUpsertOverride = (table, payload) async {
        syncedCount++;
      };
      routesRepo.currentUserIdOverride = () => 'user_123';
      routesRepo.remoteUpsertOverride = (table, payload) async {};

      final monitor = ConnectivityMonitor(
        debounceDuration: const Duration(milliseconds: 20),
      );

      final coordinator = OutdoorSyncCoordinator(
        activityRepository: actRepo,
        routesRepository: routesRepo,
        connectivityMonitor: monitor,
      );

      // Initially offline
      monitor.notifyConnectivityChange(false);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Network restored
      monitor.notifyConnectivityChange(true);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(syncedCount, equals(1));
      final stored = await actRepo.getActivityById('act_reconnect');
      expect(stored!.isSynced, isTrue);

      coordinator.dispose();
      monitor.dispose();
    });

    test('22. Failed reconnect sync handles server unreachable gracefully with bounded backoff', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final actRepo = OutdoorActivityRepository(storage: storage);
      final routesRepo = SavedRoutesRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_reconnect_fail', isSynced: false));

      actRepo.currentUserIdOverride = () => 'user_123';
      actRepo.remoteUpsertOverride = (table, payload) async {
        throw Exception('Supabase 503 Service Unavailable');
      };

      final coordinator = OutdoorSyncCoordinator(
        activityRepository: actRepo,
        routesRepository: routesRepo,
      );

      // Reconnect attempt handles network error cleanly without throwing unhandled exceptions
      final result = await coordinator.syncAll(trigger: 'connectivity_restored');

      expect(result.activitiesSynced, equals(0));
      expect(result.routesSynced, equals(0));
      expect(result.isAlreadyRunning, isFalse);
      expect(coordinator.isSyncing, isFalse);

      // Local item remains safe and pending
      final stored = await actRepo.getActivityById('act_reconnect_fail');
      expect(stored!.isSynced, isFalse);

      coordinator.dispose();
    });
  });
}

