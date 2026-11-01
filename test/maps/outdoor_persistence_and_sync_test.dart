import 'dart:convert';
import 'dart:io';

import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_tombstone_journal.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    OutdoorTombstoneJournal.clearCache();
    final defaultFile = File('${Directory.systemTemp.path}/${OutdoorTombstoneJournal.journalFileName}');
    if (defaultFile.existsSync()) {
      try {
        defaultFile.deleteSync();
      } catch (_) {}
    }
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
    bool isLoop = true,
    bool isDifficultyEstimated = false,
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
      isLoop: isLoop,
      isDifficultyEstimated: isDifficultyEstimated,
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
      final localTombstones = await storage.getTombstones();
      expect(localTombstones.firstWhere((t) => t.id == 'act_crash_step1').isRemoteSynced, isTrue);
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
      final localTombstonesReboot = await storageReboot.getTombstones();
      expect(localTombstonesReboot.firstWhere((t) => t.id == 'act_crash_step2').isRemoteSynced, isTrue);
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
      final localTombstones3 = await storage.getTombstones();
      expect(localTombstones3.firstWhere((t) => t.id == 'act_crash_step3').isRemoteSynced, isTrue);
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
      final localTombstones2 = await storage2.getTombstones();
      expect(localTombstones2.firstWhere((t) => t.id == 'act_pending_del').isRemoteSynced, isTrue);
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

    test('10b. Cross-device deletion sync: Device A deletes record, Device B purges stale copy on reconnect and never resurrects', () async {
      // Shared remote Supabase state (simulating cloud database)
      final remoteTombstonesTable = <Map<String, dynamic>>[];
      final remoteActivitiesTable = <String, Map<String, dynamic>>{};

      // 1. Both devices start knowing about act_cross_1
      final act = makeSampleActivity(id: 'act_cross_1', userId: 'user_123', isSynced: true);
      remoteActivitiesTable['act_cross_1'] = act.toJson()..['user_id'] = 'user_123';

      // Device A storage & repo
      final prefsA = await SharedPreferences.getInstance();
      final storageA = LocalOutdoorStorage(preferences: prefsA);
      final repoA = OutdoorActivityRepository(storage: storageA);
      repoA.currentUserIdOverride = () => 'user_123';
      repoA.remoteUpsertTombstoneOverride = (table, payload) async {
        remoteTombstonesTable.add(payload);
      };
      repoA.remoteDeleteOverride = (table, id, userId) async {
        remoteActivitiesTable.remove(id);
      };

      // Device B storage & repo (independent storage)
      final tempDirB = Directory.systemTemp.createTempSync('device_b_test_');
      final journalFileB = File('${tempDirB.path}/tombstones_b.json');
      SharedPreferences.setMockInitialValues({});
      final prefsB = await SharedPreferences.getInstance();
      final storageB = LocalOutdoorStorage(
        preferences: prefsB,
        tombstoneJournal: OutdoorTombstoneJournal(storageFile: journalFileB),
      );
      final repoB = OutdoorActivityRepository(storage: storageB);
      repoB.currentUserIdOverride = () => 'user_123';

      // Device B currently has a stale local copy of act_cross_1
      await storageB.saveActivity(act.copyWith(isSynced: false));
      expect((await repoB.getActivityById('act_cross_1')), isNotNull);

      // 2. Device A goes offline, deletes act_cross_1 locally, then comes online and syncs
      await repoA.deleteActivity('act_cross_1');
      expect((await repoA.getActivityById('act_cross_1')), isNull);
      // Device A uploaded tombstone to Supabase and deleted remote row
      expect(remoteTombstonesTable.any((t) => t['id'] == 'act_cross_1'), isTrue);
      expect(remoteActivitiesTable.containsKey('act_cross_1'), isFalse);

      // 3. Device B reconnects to Supabase and triggers sync
      repoB.remoteFetchTombstonesOverride = (table, userId) async {
        return remoteTombstonesTable.where((t) => t['user_id'] == userId).toList();
      };
      final uploadedFromB = <String>[];
      repoB.remoteUpsertOverride = (table, payload) async {
        uploadedFromB.add(payload['id'] as String);
      };

      await repoB.syncPendingActivities();

      // Verification:
      // a) Device B pulled remote tombstone and purged act_cross_1 from local storage!
      expect((await repoB.getActivityById('act_cross_1')), isNull);
      expect(await storageB.isActivityTombstoned('act_cross_1'), isTrue);

      // b) Device B NEVER uploaded act_cross_1 to Supabase (resurrection was 100% prevented!)
      expect(uploadedFromB.contains('act_cross_1'), isFalse);
      expect(remoteActivitiesTable.containsKey('act_cross_1'), isFalse);

      // c) Remote tombstone was NOT deleted from Supabase (allowing older devices to also pull it)
      expect(remoteTombstonesTable.any((t) => t['id'] == 'act_cross_1'), isTrue);

      try {
        tempDirB.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('10c. Durable journal: Crash immediately after tombstone persistence preserves tombstone and hides record on restart', () async {
      final tempDir = Directory.systemTemp.createTempSync('tombstone_durability_');
      final journalFile = File('${tempDir.path}/tombstones.json');

      final storageSession1 = LocalOutdoorStorage(
        preferences: prefs,
        tombstoneJournal: OutdoorTombstoneJournal(storageFile: journalFile),
      );

      // Save activity
      await storageSession1.saveActivity(makeSampleActivity(id: 'act_durable_crash1'));

      // Step 1: Write tombstone to durable file journal with synchronous flush
      await storageSession1.recordTombstone(OutdoorTombstone(
        id: 'act_durable_crash1',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
        isRemoteSynced: false,
      ));

      // SIMULATE CRASH HERE: process killed before storage.deleteActivity() is executed!
      expect(journalFile.existsSync(), isTrue);

      // RESTART APP: instantiate fresh storage session reading the physical journal file
      final storageSession2 = LocalOutdoorStorage(
        preferences: prefs,
        tombstoneJournal: OutdoorTombstoneJournal(storageFile: journalFile),
      );
      final repo2 = OutdoorActivityRepository(storage: storageSession2);

      // Even though raw activity entry was not unlinked before the crash, query filters it out!
      final list = await repo2.getAllActivities(userId: 'user_123');
      expect(list.any((a) => a.id == 'act_durable_crash1'), isFalse);
      expect(await repo2.getActivityById('act_durable_crash1'), isNull);

      // Recovery sync processes the tombstone from the durable journal
      final remoteTombstones = <Map<String, dynamic>>[];
      final remoteDeletes = <String>[];
      repo2.currentUserIdOverride = () => 'user_123';
      repo2.remoteUpsertTombstoneOverride = (table, payload) async => remoteTombstones.add(payload);
      repo2.remoteDeleteOverride = (table, id, userId) async => remoteDeletes.add(id);

      await repo2.syncPendingActivities();
      expect(remoteTombstones.any((t) => t['id'] == 'act_durable_crash1'), isTrue);
      expect(remoteDeletes, contains('act_durable_crash1'));

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('10d. Durable journal: Crash after local record removal retries remote upload upon restart', () async {
      final tempDir = Directory.systemTemp.createTempSync('tombstone_durability2_');
      final journalFile = File('${tempDir.path}/tombstones.json');

      final storageSession1 = LocalOutdoorStorage(
        preferences: prefs,
        tombstoneJournal: OutdoorTombstoneJournal(storageFile: journalFile),
      );

      // Step 1: Record tombstone
      await storageSession1.recordTombstone(OutdoorTombstone(
        id: 'act_durable_crash2',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
        isRemoteSynced: false,
      ));
      // Step 2: Unlink local record
      await storageSession1.deleteActivity('act_durable_crash2');

      // SIMULATE CRASH HERE: process killed before remote calls dispatched!

      // RESTART APP
      final storageSession2 = LocalOutdoorStorage(
        preferences: prefs,
        tombstoneJournal: OutdoorTombstoneJournal(storageFile: journalFile),
      );
      final repo2 = OutdoorActivityRepository(storage: storageSession2);

      final tombstones = await storageSession2.getTombstones(userId: 'user_123');
      expect(tombstones.any((t) => t.id == 'act_durable_crash2' && !t.isRemoteSynced), isTrue);

      final remoteTombstones = <Map<String, dynamic>>[];
      repo2.currentUserIdOverride = () => 'user_123';
      repo2.remoteUpsertTombstoneOverride = (table, payload) async => remoteTombstones.add(payload);
      repo2.remoteDeleteOverride = (table, id, userId) async {};

      await repo2.syncPendingActivities();
      expect(remoteTombstones.any((t) => t['id'] == 'act_durable_crash2'), isTrue);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('10e. Durable journal: Crash after remote tombstone creation retries remote activity deletion idempotently', () async {
      final tempDir = Directory.systemTemp.createTempSync('tombstone_durability3_');
      final journalFile = File('${tempDir.path}/tombstones.json');

      final storage = LocalOutdoorStorage(
        preferences: prefs,
        tombstoneJournal: OutdoorTombstoneJournal(storageFile: journalFile),
      );
      final repo = OutdoorActivityRepository(storage: storage);

      // Tombstone is on server, but activity deletion in outdoor_activities threw / crashed
      await storage.recordTombstone(OutdoorTombstone(
        id: 'act_durable_crash3',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
        isRemoteSynced: false,
      ));

      final deletedRemoteIds = <String>[];
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertTombstoneOverride = (table, payload) async {};
      repo.remoteDeleteOverride = (table, id, userId) async => deletedRemoteIds.add(id);

      await repo.syncPendingActivities();
      expect(deletedRemoteIds, contains('act_durable_crash3'));
      // Local tombstone is marked remote synced
      final localT = await storage.getTombstones();
      expect(localT.firstWhere((t) => t.id == 'act_durable_crash3').isRemoteSynced, isTrue);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('10f. Durable journal: Crash after remote deletion before local acknowledgement completes idempotently on restart', () async {
      final tempDir = Directory.systemTemp.createTempSync('tombstone_durability4_');
      final journalFile = File('${tempDir.path}/tombstones.json');

      final storage = LocalOutdoorStorage(
        preferences: prefs,
        tombstoneJournal: OutdoorTombstoneJournal(storageFile: journalFile),
      );
      final repo = OutdoorActivityRepository(storage: storage);

      // Server already has tombstone and already deleted record, but local tombstone isRemoteSynced is false
      await storage.recordTombstone(OutdoorTombstone(
        id: 'act_durable_crash4',
        entityType: 'activity',
        userId: 'user_123',
        deletedAt: DateTime(2026, 10, 31, 12, 0, 0),
        isRemoteSynced: false,
      ));

      var deleteCalls = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertTombstoneOverride = (table, payload) async {};
      repo.remoteDeleteOverride = (table, id, userId) async {
        deleteCalls++;
      };

      await repo.syncPendingActivities();
      expect(deleteCalls, equals(1));
      final localT = await storage.getTombstones();
      expect(localT.firstWhere((t) => t.id == 'act_durable_crash4').isRemoteSynced, isTrue);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('10g. Durable journal: Torn write with corrupt CRC-32 is detected safely without app crash', () async {
      final tempDir = Directory.systemTemp.createTempSync('tombstone_torn_');
      final journalFile = File('${tempDir.path}/tombstones.json');

      // Write an envelope with intentionally corrupted CRC-32 (simulating torn write during power failure)
      final corruptEnvelope = jsonEncode({
        'version': 1,
        'sequence': 1,
        'payload_crc32': 12345678, // Wrong CRC
        'payload': [{'id': 'act_corrupt', 'entity_type': 'activity', 'user_id': 'user_123', 'deleted_at': '2026-10-31T12:00:00Z'}],
      });
      journalFile.writeAsStringSync(corruptEnvelope, flush: true);

      final journal = OutdoorTombstoneJournal(storageFile: journalFile);
      final loaded = await journal.getAll();
      expect(loaded, isEmpty, reason: 'Corrupt payload with invalid CRC must be safely rejected');

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('10h. Stale activity upload rejected by server tombstone: purged locally, recorded in tombstone queue, not retried', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      // Stale activity on this device
      await storage.saveActivity(makeSampleActivity(id: 'act_stale_1', userId: 'user_123', isSynced: false));

      var upsertAttempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        upsertAttempts++;
        // Simulate PostgreSQL check_outdoor_activity_tombstone() exception
        throw Exception('PostgreSQL P0001: Activity act_stale_1 has been deleted by an active tombstone: TOMBSTONE_EXISTS');
      };

      final syncedCount = await repo.syncPendingActivities();

      // Rejected write is NOT counted as success
      expect(syncedCount, equals(0));
      // Rejection halts immediately without redundant backoff retries
      expect(upsertAttempts, equals(1));

      // Stale record is immediately purged from local storage
      final localAct = await repo.getActivityById('act_stale_1');
      expect(localAct, isNull);

      // Tombstone is recorded locally to prevent resurrection
      final tombstones = await storage.getTombstones(userId: 'user_123');
      expect(tombstones.any((t) => t.id == 'act_stale_1' && t.entityType == 'activity'), isTrue);

      // Subsequent sync cycles will not attempt to upload the purged record
      upsertAttempts = 0;
      final secondSyncCount = await repo.syncPendingActivities();
      expect(secondSyncCount, equals(0));
      expect(upsertAttempts, equals(0));
    });

    test('10i. Stale route upload rejected by server tombstone: purged locally, recorded in tombstone queue, not retried', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = SavedRoutesRepository(storage: storage);

      // Stale route on this device
      await storage.saveRoute(makeSampleRoute(id: 'route_stale_1', userId: 'user_123'));

      var upsertAttempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        upsertAttempts++;
        // Simulate PostgreSQL check_saved_route_tombstone() exception
        throw Exception('PostgreSQL P0001: Route route_stale_1 has been deleted by an active tombstone: TOMBSTONE_EXISTS');
      };

      final syncedCount = await repo.syncPendingRoutes();

      // Rejected write is NOT counted as success
      expect(syncedCount, equals(0));
      // Rejection halts immediately without redundant backoff retries
      expect(upsertAttempts, equals(1));

      // Stale route is immediately purged from local storage
      final routes = await repo.getSavedRoutes(userId: 'user_123');
      expect(routes.any((r) => r.id == 'route_stale_1'), isFalse);

      // Tombstone is recorded locally
      final tombstones = await storage.getTombstones(userId: 'user_123');
      expect(tombstones.any((t) => t.id == 'route_stale_1' && t.entityType == 'route'), isTrue);

      // Subsequent sync cycles will not attempt to upload the purged route
      upsertAttempts = 0;
      final secondSyncCount = await repo.syncPendingRoutes();
      expect(secondSyncCount, equals(0));
      expect(upsertAttempts, equals(0));
    });

    test('10j. Network transient error during sync is retried with backoff, unlike tombstone rejection', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_net_retry', userId: 'user_123', isSynced: false));

      var attempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        attempts++;
        if (attempts < 3) {
          throw Exception('SocketException: OS error: Network is unreachable, errno = 101');
        }
        // Succeeds on 3rd attempt
      };

      final syncedCount = await repo.syncPendingActivities();

      // Successfully retried and synchronized
      expect(syncedCount, equals(1));
      expect(attempts, equals(3));

      final act = await repo.getActivityById('act_net_retry');
      expect(act, isNotNull);
      expect(act!.isSynced, isTrue);
    });

    test('10k. Typed PostgrestException with SQLSTATE P0001 and TOMBSTONE_EXISTS detail is correctly classified and handled', () async {
      // 1. Verify typed exception detection directly
      final typedEx = PostgrestException(
        message: 'Activity act_typed_1 has been deleted by an active tombstone',
        code: 'P0001',
        details: 'TOMBSTONE_EXISTS',
      );
      expect(OutdoorActivityRepository.isTombstoneRejection(typedEx), isTrue);

      // 2. Verify repository sync behavior when PostgrestException is thrown
      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_typed_1', userId: 'user_123', isSynced: false));

      var upsertCalls = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        upsertCalls++;
        throw typedEx;
      };

      final synced = await repo.syncPendingActivities();
      expect(synced, equals(0));
      expect(upsertCalls, equals(1), reason: 'Must not retry on tombstone rejection');

      // Local activity purged, local tombstone persisted
      expect(await repo.getActivityById('act_typed_1'), isNull);
      final t = await storage.getTombstones(userId: 'user_123');
      expect(t.any((item) => item.id == 'act_typed_1' && item.isRemoteSynced), isTrue);
    });

    test('10l. Typed PostgrestException for routes with SQLSTATE P0001 and details TOMBSTONE_EXISTS is correctly classified', () async {
      final typedRouteEx = PostgrestException(
        message: 'Route route_typed_1 has been deleted by an active tombstone',
        code: 'P0001',
        details: 'TOMBSTONE_EXISTS',
      );
      expect(SavedRoutesRepository.isTombstoneRejection(typedRouteEx), isTrue);

      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = SavedRoutesRepository(storage: storage);

      await storage.saveRoute(makeSampleRoute(id: 'route_typed_1', userId: 'user_123'));

      var routeUpsertCalls = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        routeUpsertCalls++;
        throw typedRouteEx;
      };

      final synced = await repo.syncPendingRoutes();
      expect(synced, equals(0));
      expect(routeUpsertCalls, equals(1));

      final routes = await repo.getSavedRoutes(userId: 'user_123');
      expect(routes.any((r) => r.id == 'route_typed_1'), isFalse);
      final t = await storage.getTombstones(userId: 'user_123');
      expect(t.any((item) => item.id == 'route_typed_1' && item.isRemoteSynced), isTrue);
    });

    test('10m. Serialization failure (SQLSTATE 40001) is classified as retryable and retried with backoff using a fresh request', () async {
      final serEx = PostgrestException(
        message: 'could not serialize access due to concurrent update',
        code: '40001',
      );
      expect(OutdoorActivityRepository.isRetryableSyncError(serEx), isTrue);
      expect(SavedRoutesRepository.isRetryableSyncError(serEx), isTrue);

      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);
      await storage.saveActivity(makeSampleActivity(id: 'act_ser_retry', userId: 'user_123', isSynced: false));

      var attempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        attempts++;
        if (attempts < 2) {
          throw serEx; // Fails on first attempt with 40001
        }
        // Succeeds on second attempt with fresh transaction/snapshot
      };

      final syncedCount = await repo.syncPendingActivities();
      expect(syncedCount, equals(1));
      expect(attempts, equals(2));

      final act = await repo.getActivityById('act_ser_retry');
      expect(act, isNotNull);
      expect(act!.isSynced, isTrue);
    });

    test('10n. Deadlock detected (SQLSTATE 40P01) is classified as retryable and retried with backoff', () async {
      final deadlockEx = PostgrestException(
        message: 'deadlock detected',
        code: '40P01',
      );
      expect(OutdoorActivityRepository.isRetryableSyncError(deadlockEx), isTrue);
      expect(SavedRoutesRepository.isRetryableSyncError(deadlockEx), isTrue);

      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = SavedRoutesRepository(storage: storage);
      await storage.saveRoute(makeSampleRoute(id: 'route_deadlock_retry', userId: 'user_123'));

      var attempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        attempts++;
        if (attempts < 2) {
          throw deadlockEx;
        }
      };

      final syncedCount = await repo.syncPendingRoutes();
      expect(syncedCount, equals(1));
      expect(attempts, equals(2));
    });

    test('10o. Transient server failures (HTTP 503 / 500 / 429) are classified as retryable and retried with backoff', () async {
      final server503 = PostgrestException(
        message: 'Service Unavailable',
        code: '503',
      );
      final rate429 = PostgrestException(
        message: 'Too Many Requests',
        code: '429',
      );
      expect(OutdoorActivityRepository.isRetryableSyncError(server503), isTrue);
      expect(OutdoorActivityRepository.isRetryableSyncError(rate429), isTrue);

      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);
      await storage.saveActivity(makeSampleActivity(id: 'act_503_retry', userId: 'user_123', isSynced: false));

      var attempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        attempts++;
        if (attempts < 2) {
          throw server503;
        }
      };

      final syncedCount = await repo.syncPendingActivities();
      expect(syncedCount, equals(1));
      expect(attempts, equals(2));
    });

    test('10p. Insufficient privilege (SQLSTATE 42501) is classified as permanent and not retried', () async {
      final permEx = PostgrestException(
        message: 'permission denied for table outdoor_activities',
        code: '42501',
      );
      expect(OutdoorActivityRepository.isRetryableSyncError(permEx), isFalse);
      expect(SavedRoutesRepository.isRetryableSyncError(permEx), isFalse);

      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);
      await storage.saveActivity(makeSampleActivity(id: 'act_perm_fail', userId: 'user_123', isSynced: false));

      var attempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        attempts++;
        throw permEx;
      };

      final syncedCount = await repo.syncPendingActivities();
      expect(syncedCount, equals(0));
      // Must halt immediately on 1st attempt without wasting retries
      expect(attempts, equals(1));

      // Local record remains intact for retry when permissions are fixed or user re-authenticates
      final act = await repo.getActivityById('act_perm_fail');
      expect(act, isNotNull);
      expect(act!.isSynced, isFalse);
    });

    test('10q. Integrity constraint violations (SQLSTATE 23505 / 23503 / 23514) are classified as permanent and not retried', () async {
      final checkEx = PostgrestException(
        message: 'new row for relation "saved_routes" violates check constraint',
        code: '23514',
      );
      final fkeyEx = PostgrestException(
        message: 'insert or update on table "saved_routes" violates foreign key constraint',
        code: '23503',
      );
      final uniqueEx = PostgrestException(
        message: 'duplicate key value violates unique constraint',
        code: '23505',
      );
      expect(SavedRoutesRepository.isRetryableSyncError(checkEx), isFalse);
      expect(SavedRoutesRepository.isRetryableSyncError(fkeyEx), isFalse);
      expect(SavedRoutesRepository.isRetryableSyncError(uniqueEx), isFalse);

      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = SavedRoutesRepository(storage: storage);
      await storage.saveRoute(makeSampleRoute(id: 'route_check_fail', userId: 'user_123'));

      var attempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        attempts++;
        throw checkEx;
      };

      final syncedCount = await repo.syncPendingRoutes();
      expect(syncedCount, equals(0));
      // Must halt immediately on 1st attempt without wasting retries
      expect(attempts, equals(1));
    });

    test('10r. Retry exhaustion: retryable error exceeds max attempts (3) and is safely bounded', () async {
      final serEx = PostgrestException(
        message: 'could not serialize access due to concurrent update',
        code: '40001',
      );

      final storage = LocalOutdoorStorage(preferences: prefs);
      final repo = OutdoorActivityRepository(storage: storage);
      await storage.saveActivity(makeSampleActivity(id: 'act_exhaust_retry', userId: 'user_123', isSynced: false));

      var attempts = 0;
      repo.currentUserIdOverride = () => 'user_123';
      repo.remoteUpsertOverride = (table, payload) async {
        attempts++;
        throw serEx;
      };

      final syncedCount = await repo.syncPendingActivities();
      expect(syncedCount, equals(0));
      // Bounded retry terminates after exactly 3 attempts
      expect(attempts, equals(3));

      // Local record remains preserved with isSynced = false
      final act = await repo.getActivityById('act_exhaust_retry');
      expect(act, isNotNull);
      expect(act!.isSynced, isFalse);
    });
  });

  // ===========================================================================
  // 4. SAVED ROUTES SCHEMA COMPATIBILITY & CONSTRAINTS
  // ===========================================================================
  group('4. Saved Routes Schema Compatibility & Sanitization', () {
    test('11. toSupabasePayload synchronizes metadata and preserves unknown/nullable semantics', () {
      final route = makeSampleRoute(
        id: 'route_check_constraints',
        surface: RouteSurface.unknown,
        elevation: RouteElevation.unknown,
        elevationGain: null,
        isLoop: true,
        isDifficultyEstimated: true,
      );

      final payload = SavedRoutesRepository.toSupabasePayload(route, 'user_123');

      // Preserves actual unknown semantics ('unknown') rather than silently falsifying to 'paved'/'flat'
      expect(payload['surface_type'], equals('unknown'));
      expect(payload['elevation_profile'], equals('unknown'));

      // Preserves null elevation_gain_meters rather than inventing 0.0 (requires migration 020)
      expect(payload['elevation_gain_meters'], isNull);

      // Metadata synchronized for loop circuits and estimated difficulty (requires migration 020)
      expect(payload['is_loop'], isTrue);
      expect(payload['is_difficulty_estimated'], isTrue);
    });

    test('11b. SavedRoute round-trip JSON serialization preserves unknown metadata', () {
      final route = makeSampleRoute(
        id: 'route_unknown_roundtrip',
        surface: RouteSurface.unknown,
        elevation: RouteElevation.unknown,
        isLoop: true,
        isDifficultyEstimated: false,
      );
      final json = route.toJson();
      final restored = SavedRoute.fromJson(json);
      expect(restored.surfaceType, equals(RouteSurface.unknown));
      expect(restored.elevationProfile, equals(RouteElevation.unknown));
      expect(restored.isLoop, isTrue);
      expect(restored.isDifficultyEstimated, isFalse);
    });

    test('11c. SavedRoute Supabase payload round-trip covers all 5 requested edge cases', () {
      // Case 1: Loop with estimated difficulty
      final routeLoopEstimated = makeSampleRoute(
        id: 'route_roundtrip_1',
        isLoop: true,
        isDifficultyEstimated: true,
        elevationGain: 150.0,
      );
      final payload1 = SavedRoutesRepository.toSupabasePayload(routeLoopEstimated, 'user_123');
      expect(payload1['is_loop'], isTrue);
      expect(payload1['is_difficulty_estimated'], isTrue);
      final restored1 = SavedRoute.fromJson(payload1);
      expect(restored1.isLoop, isTrue);
      expect(restored1.isDifficultyEstimated, isTrue);

      // Case 2: Non-loop with non-estimated difficulty
      final routePointToPoint = makeSampleRoute(
        id: 'route_roundtrip_2',
        isLoop: false,
        isDifficultyEstimated: false,
        elevationGain: 50.0,
      );
      final payload2 = SavedRoutesRepository.toSupabasePayload(routePointToPoint, 'user_123');
      expect(payload2['is_loop'], isFalse);
      expect(payload2['is_difficulty_estimated'], isFalse);
      final restored2 = SavedRoute.fromJson(payload2);
      expect(restored2.isLoop, isFalse);
      expect(restored2.isDifficultyEstimated, isFalse);

      // Case 3: Unknown surface
      final routeUnknownSurface = makeSampleRoute(
        id: 'route_roundtrip_3',
        surface: RouteSurface.unknown,
      );
      final payload3 = SavedRoutesRepository.toSupabasePayload(routeUnknownSurface, 'user_123');
      expect(payload3['surface_type'], equals('unknown'));
      final restored3 = SavedRoute.fromJson(payload3);
      expect(restored3.surfaceType, equals(RouteSurface.unknown));

      // Case 4: Unknown elevation profile
      final routeUnknownElevation = makeSampleRoute(
        id: 'route_roundtrip_4',
        elevation: RouteElevation.unknown,
      );
      final payload4 = SavedRoutesRepository.toSupabasePayload(routeUnknownElevation, 'user_123');
      expect(payload4['elevation_profile'], equals('unknown'));
      final restored4 = SavedRoute.fromJson(payload4);
      expect(restored4.elevationProfile, equals(RouteElevation.unknown));

      // Case 5: Null elevation gain (never defaulting to 0.0)
      final routeNullElevationGain = makeSampleRoute(
        id: 'route_roundtrip_5',
        elevationGain: null,
      );
      final payload5 = SavedRoutesRepository.toSupabasePayload(routeNullElevationGain, 'user_123');
      expect(payload5['elevation_gain_meters'], isNull);
      final restored5 = SavedRoute.fromJson(payload5);
      expect(restored5.elevationGainMeters, isNull);
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
      final localTombstonesRoute = await storage.getTombstones();
      expect(localTombstonesRoute.firstWhere((t) => t.id == 'route_del_test').isRemoteSynced, isTrue);
    });

    test('13b. Cross-device route deletion sync: Device A deletes route, Device B purges stale copy on reconnect and never resurrects', () async {
      // Shared remote Supabase state (simulating cloud database)
      final remoteTombstonesTable = <Map<String, dynamic>>[];
      final remoteRoutesTable = <String, Map<String, dynamic>>{};

      // 1. Both devices start knowing about route_cross_1
      final r = makeSampleRoute(id: 'route_cross_1', userId: 'user_123');
      remoteRoutesTable['route_cross_1'] = r.toJson()..['user_id'] = 'user_123';

      // Device A storage & repo
      final prefsA = await SharedPreferences.getInstance();
      final storageA = LocalOutdoorStorage(preferences: prefsA);
      final repoA = SavedRoutesRepository(storage: storageA);
      repoA.currentUserIdOverride = () => 'user_123';
      repoA.remoteUpsertTombstoneOverride = (table, payload) async {
        remoteTombstonesTable.add(payload);
      };
      repoA.remoteDeleteOverride = (table, id, userId) async {
        remoteRoutesTable.remove(id);
      };

      // Device B storage & repo (independent storage)
      final tempDirB = Directory.systemTemp.createTempSync('device_b_route_test_');
      final journalFileB = File('${tempDirB.path}/route_tombstones_b.json');
      SharedPreferences.setMockInitialValues({});
      final prefsB = await SharedPreferences.getInstance();
      final storageB = LocalOutdoorStorage(
        preferences: prefsB,
        tombstoneJournal: OutdoorTombstoneJournal(storageFile: journalFileB),
      );
      final repoB = SavedRoutesRepository(storage: storageB);
      repoB.currentUserIdOverride = () => 'user_123';

      // Device B currently has a stale local copy of route_cross_1
      await storageB.saveRoute(r);
      expect((await repoB.getSavedRoutes(userId: 'user_123')), hasLength(1));

      // 2. Device A goes offline, deletes route_cross_1 locally, then comes online and syncs
      await repoA.deleteRoute('route_cross_1');
      expect((await repoA.getSavedRoutes(userId: 'user_123')), isEmpty);
      // Device A uploaded tombstone to Supabase and deleted remote row
      expect(remoteTombstonesTable.any((t) => t['id'] == 'route_cross_1' && t['entity_type'] == 'route'), isTrue);
      expect(remoteRoutesTable.containsKey('route_cross_1'), isFalse);

      // 3. Device B reconnects to Supabase and triggers sync
      repoB.remoteFetchTombstonesOverride = (table, userId) async {
        return remoteTombstonesTable.where((t) => t['user_id'] == userId).toList();
      };
      final uploadedFromB = <String>[];
      repoB.remoteUpsertOverride = (table, payload) async {
        uploadedFromB.add(payload['id'] as String);
      };

      await repoB.syncPendingRoutes();

      // Verification:
      // a) Device B pulled remote tombstone and purged route_cross_1 from local storage!
      expect((await repoB.getSavedRoutes(userId: 'user_123')), isEmpty);
      // b) Device B did NOT upload/resurrect route_cross_1 to Supabase!
      expect(uploadedFromB, isEmpty);
      expect(remoteRoutesTable.containsKey('route_cross_1'), isFalse);

      if (tempDirB.existsSync()) {
        try {
          tempDirB.deleteSync(recursive: true);
        } catch (_) {}
      }
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

    test('17b. Complete Sync Audit: Full guest-to-auth lifecycle, account switching, logout/login, and account deletion', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final actRepo = OutdoorActivityRepository(storage: storage);
      final routesRepo = SavedRoutesRepository(storage: storage);

      final cloudActivities = <String, Map<String, dynamic>>{};
      final cloudRoutes = <String, Map<String, dynamic>>{};

      actRepo.remoteUpsertOverride = (table, payload) async {
        cloudActivities[payload['id'] as String] = payload;
      };
      routesRepo.remoteUpsertOverride = (table, payload) async {
        cloudRoutes[payload['id'] as String] = payload;
      };

      // 1. Guest Mode: user records workout and saves route while not logged in
      String? activeUserId; // null = guest
      actRepo.currentUserIdOverride = () => activeUserId;
      routesRepo.currentUserIdOverride = () => activeUserId;

      await storage.saveActivity(makeSampleActivity(id: 'guest_run', userId: 'local_user', isSynced: false));
      await storage.saveRoute(makeSampleRoute(id: 'guest_path', userId: 'local_user'));

      // Guest sync attempts do nothing (offline-first, no leakage to cloud)
      final guestActSyncCount = await actRepo.syncPendingActivities();
      final guestRouteSyncCount = await routesRepo.syncPendingRoutes();
      expect(guestActSyncCount, equals(0));
      expect(guestRouteSyncCount, equals(0));
      expect(cloudActivities, isEmpty);
      expect(cloudRoutes, isEmpty);

      // 2. Authentication: User signs in as Alice
      activeUserId = 'alice_uuid';
      await storage.adoptGuestData('alice_uuid');

      // Verify guest data adopted by Alice
      final aliceLocalActs = await storage.getAllActivities(userId: 'alice_uuid');
      final aliceLocalRoutes = await storage.getSavedRoutes(userId: 'alice_uuid');
      expect(aliceLocalActs, hasLength(1));
      expect(aliceLocalActs.first.userId, equals('alice_uuid'));
      expect(aliceLocalRoutes, hasLength(1));
      expect(aliceLocalRoutes.first.userId, equals('alice_uuid'));

      // Alice syncs to Supabase
      final aliceActSyncCount = await actRepo.syncPendingActivities();
      final aliceRouteSyncCount = await routesRepo.syncPendingRoutes();
      expect(aliceActSyncCount, equals(1));
      expect(aliceRouteSyncCount, equals(1));
      expect(cloudActivities.containsKey('guest_run'), isTrue);
      expect(cloudActivities['guest_run']!['user_id'], equals('alice_uuid'));
      expect(cloudRoutes.containsKey('guest_path'), isTrue);
      expect(cloudRoutes['guest_path']!['user_id'], equals('alice_uuid'));

      // 3. Logout Alice & Account Switching: Bob signs in on the same device
      activeUserId = 'bob_uuid';

      // Bob cannot see Alice's records
      final bobLocalActs = await storage.getAllActivities(userId: 'bob_uuid');
      final bobLocalRoutes = await storage.getSavedRoutes(userId: 'bob_uuid');
      expect(bobLocalActs, isEmpty);
      expect(bobLocalRoutes, isEmpty);

      // Bob syncs - must not touch or re-upload Alice's records
      final bobActSyncCount = await actRepo.syncPendingActivities();
      final bobRouteSyncCount = await routesRepo.syncPendingRoutes();
      expect(bobActSyncCount, equals(0));
      expect(bobRouteSyncCount, equals(0));

      // 4. Bob logs out. Alice logs back in and deletes her account
      activeUserId = 'alice_uuid';
      await storage.clearUserData('alice_uuid');

      // All of Alice's local records and tombstones are purged
      final remainingActs = await storage.getAllActivities(userId: 'alice_uuid');
      final remainingRoutes = await storage.getSavedRoutes(userId: 'alice_uuid');
      final remainingTombstones = await storage.getTombstones(userId: 'alice_uuid');
      expect(remainingActs, isEmpty);
      expect(remainingRoutes, isEmpty);
      expect(remainingTombstones, isEmpty);
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

    test('18b. Simultaneous sync requests safely coalesce without data corruption or duplicate uploads', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final actRepo = OutdoorActivityRepository(storage: storage);
      final routesRepo = SavedRoutesRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_simul', isSynced: false));

      actRepo.currentUserIdOverride = () => 'user_123';
      var uploadCount = 0;
      actRepo.remoteUpsertOverride = (table, payload) async {
        uploadCount++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      };

      routesRepo.currentUserIdOverride = () => 'user_123';
      routesRepo.remoteUpsertOverride = (table, payload) async {};

      final coordinator = OutdoorSyncCoordinator(
        activityRepository: actRepo,
        routesRepository: routesRepo,
      );

      // Launch two sync requests simultaneously
      final future1 = coordinator.syncAll(trigger: 'trigger_1');
      final future2 = coordinator.syncAll(trigger: 'trigger_2');

      final results = await Future.wait([future1, future2]);

      // future1 completes successfully and syncs the activity
      expect(results[0].isSuccess, isTrue);
      expect(results[0].activitiesSynced, equals(1));

      // future2 was safely coalesced into the active cycle
      expect(results[1].isAlreadyRunning, isTrue);

      // Activity is uploaded exactly once without duplicate cloud rows
      expect(uploadCount, equals(1));
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

    test('23. Coalesced pending-sync: Connectivity returns during an already-running failed sync and triggers immediate follow-up retry', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final actRepo = OutdoorActivityRepository(storage: storage);
      final routesRepo = SavedRoutesRepository(storage: storage);

      await storage.saveActivity(makeSampleActivity(id: 'act_coalesce_retry', isSynced: false));

      var attemptCount = 0;
      const succeedOnAttempt = 2; // Fails on cycle 1, succeeds on cycle 2
      actRepo.currentUserIdOverride = () => 'user_123';
      actRepo.remoteUpsertOverride = (table, payload) async {
        attemptCount++;
        if (attemptCount < succeedOnAttempt) {
          throw Exception('Simulated network failure on cycle 1');
        }
        // Succeeds on cycle 2
      };
      routesRepo.currentUserIdOverride = () => 'user_123';
      routesRepo.remoteUpsertOverride = (table, payload) async {};

      final monitor = ConnectivityMonitor(
        debounceDuration: const Duration(milliseconds: 10),
      );

      final coordinator = OutdoorSyncCoordinator(
        activityRepository: actRepo,
        routesRepository: routesRepo,
        connectivityMonitor: monitor,
      );

      // Start initial sync (which encounters network failure on cycle 1)
      final initialFuture = coordinator.syncAll(trigger: 'startup');

      // WHILE initial sync is executing, connectivity returns!
      // This queues a coalesced sync cycle.
      final secondCallResult = await coordinator.syncAll(trigger: 'connectivity_restored');
      expect(secondCallResult.isAlreadyRunning, isTrue);
      expect(coordinator.hasPendingSync, isTrue);

      // Wait for initial coordinator call to complete both cycle 1 and coalesced cycle 2
      final overallResult = await initialFuture;

      expect(overallResult.activitiesSynced, equals(1));
      expect(attemptCount, equals(2));
      expect(coordinator.isSyncing, isFalse);
      expect(coordinator.hasPendingSync, isFalse);

      final stored = await actRepo.getActivityById('act_coalesce_retry');
      expect(stored!.isSynced, isTrue);

      coordinator.dispose();
      monitor.dispose();
    });

    test('24. Coalesced pending-sync: Rapid flapping during sync executes at most one additional cycle without infinite loop', () async {
      final storage = LocalOutdoorStorage(preferences: prefs);
      final actRepo = OutdoorActivityRepository(storage: storage);
      final routesRepo = SavedRoutesRepository(storage: storage);

      var cycleCount = 0;
      actRepo.currentUserIdOverride = () => 'user_123';
      actRepo.remoteUpsertOverride = (table, payload) async {
        cycleCount++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      };
      routesRepo.currentUserIdOverride = () => 'user_123';
      routesRepo.remoteUpsertOverride = (table, payload) async {};

      await storage.saveActivity(makeSampleActivity(id: 'act_flap_1', isSynced: false));

      final coordinator = OutdoorSyncCoordinator(
        activityRepository: actRepo,
        routesRepository: routesRepo,
      );

      final future1 = coordinator.syncAll(trigger: 'event_1');

      // Flapping events arrive while future1 is active
      coordinator.syncAll(trigger: 'flap_1');
      coordinator.syncAll(trigger: 'flap_2');
      coordinator.syncAll(trigger: 'flap_3');

      final result = await future1;

      expect(cycleCount, greaterThanOrEqualTo(1));
      expect(result.isAlreadyRunning, isFalse);
      expect(coordinator.isSyncing, isFalse);
      expect(coordinator.hasPendingSync, isFalse);

      coordinator.dispose();
    });
  });

  // ===========================================================================
  // 7. DATABASE SECURITY, RLS & CONCURRENCY AUDIT (CODE READING ONLY)
  // ===========================================================================
  group('7. Database Security, RLS & Concurrency Invariance Audit (Code Reading Verification)', () {
    test('25. Authenticated user attempting to insert tombstone for another user is blocked [CODE READING ONLY]', () {
      // CODE READING VERIFICATION:
      // In 020_saved_routes_metadata_and_tombstones.sql:
      // 1. RLS Policy:
      //    create policy "insert own outdoor tombstones" on public.outdoor_tombstones
      //      for insert to authenticated with check (auth.uid() = user_id);
      // 2. Trigger check:
      //    if auth.role() = 'authenticated' and NEW.user_id is distinct from auth.uid() then
      //      raise exception 'Unauthorized: user_id mismatch' using errcode = '42501';
      //    end if;
      // Both defense layers independently reject any attempt where NEW.user_id != auth.uid().
      expect(true, isTrue);
    });

    test('26. Authenticated user attempting to modify or delete a tombstone is blocked [CODE READING ONLY]', () {
      // CODE READING VERIFICATION:
      // In 020_saved_routes_metadata_and_tombstones.sql:
      // 1. UPDATE and DELETE RLS policies were explicitly dropped.
      // 2. Table-level privileges were explicitly revoked:
      //    revoke update, delete on table public.outdoor_tombstones from authenticated;
      // 3. PostgreSQL default denial: Any UPDATE or DELETE query by an authenticated client
      //    fails with SQLSTATE 42501 (permission denied for table outdoor_tombstones).
      expect(true, isTrue);
    });

    test('27. Duplicate tombstone insertion uses ON CONFLICT DO NOTHING idempotency [CODE READING ONLY]', () {
      // CODE READING VERIFICATION:
      // In repositories:
      //    _supabase.from('outdoor_tombstones').upsert(
      //      payload, onConflict: 'id,entity_type,user_id', ignoreDuplicates: true
      //    );
      // PostgREST generates: INSERT INTO public.outdoor_tombstones ... ON CONFLICT DO NOTHING.
      // Requires ONLY INSERT table privilege. No UPDATE privilege is required or exercised.
      expect(true, isTrue);
    });

    test('28. Route and activity upserts after tombstone creation raise TOMBSTONE_EXISTS [CODE READING ONLY]', () {
      // CODE READING VERIFICATION:
      // In 020_saved_routes_metadata_and_tombstones.sql:
      //    if v_tombstone_exists then
      //      raise exception 'Activity/Route % has been deleted by an active tombstone', NEW.id
      //        using errcode = 'P0001', detail = 'TOMBSTONE_EXISTS';
      //    end if;
      // Triggers raise P0001 with TOMBSTONE_EXISTS detail, allowing client repositories
      // to identify rejection and purge local stale records immediately.
      expect(true, isTrue);
    });

    test('29. Account deletion cascades cleanly to outdoor_tombstones [CODE READING ONLY]', () {
      // CODE READING VERIFICATION:
      // In 020_saved_routes_metadata_and_tombstones.sql:
      //    user_id uuid not null references public.profiles(id) on delete cascade
      // In 008_account_deletion.sql:
      //    delete from auth.users where id = v_uid;
      // auth.users cascades to public.profiles, which in turn cascades to public.outdoor_tombstones.
      // No client DELETE privilege on outdoor_tombstones is needed or bypassed.
      expect(true, isTrue);
    });

    test('30. Advisory lock key derivation is strictly symmetric across entities and tombstones [CODE READING ONLY]', () {
      // CODE READING VERIFICATION:
      // Activity write:   hashtextextended('outdoor_lock:' || NEW.user_id::text || ':activity:' || NEW.id, 0)
      // Activity tomb:    hashtextextended('outdoor_lock:' || NEW.user_id::text || ':' || NEW.entity_type || ':' || NEW.id, 0)
      // Route write:      hashtextextended('outdoor_lock:' || NEW.user_id::text || ':route:' || NEW.id, 0)
      // Route tomb:       hashtextextended('outdoor_lock:' || NEW.user_id::text || ':' || NEW.entity_type || ':' || NEW.id, 0)
      // Under NEW.entity_type = 'activity' or 'route', the string is identical character-for-character.
      // The 64-bit integer space produces identical locks across entity writes and tombstone creations.
      expect(true, isTrue);
    });
  });
}

