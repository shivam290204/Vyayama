import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/services/notification_service.dart';

/// Top-level callback dispatcher executed in a headless Dart isolate by Android WorkManager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: '.env', isOptional: true);
      await NotificationService.instance.initialize();

      if (!Env.isSupabaseConfigured) {
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      var userId = prefs.getString('last_signed_in_user_id');

      // Initialize Supabase in this background isolate if needed
      try {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          publishableKey: Env.supabaseAnonKey,
        );
      } catch (_) {}

      final client = Supabase.instance.client;
      userId ??= client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty) {
        return true;
      }

      final isUuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(userId);

      if (!isUuid) {
        return true;
      }

      final notifiedIds =
          prefs.getStringList('notified_social_ids')?.toSet() ?? <String>{};

      // 1. Check for pending incoming friend requests
      try {
        final pendingRequests = await client
            .from('friendships')
            .select('id, requester_id, status')
            .eq('addressee_id', userId)
            .eq('status', 'pending');

        for (final row in pendingRequests) {
            final rMap = Map<String, dynamic>.from(row as Map);
            final reqId = rMap['id'] as String;
            final reqKey = 'req_$reqId';

            if (!notifiedIds.contains(reqKey)) {
              notifiedIds.add(reqKey);
              final requesterId = rMap['requester_id'] as String;
              String senderName = 'A friend';

              try {
                final pRes = await client
                    .from('profiles')
                    .select('name, username')
                    .eq('id', requesterId)
                    .maybeSingle();
                if (pRes != null) {
                  final name = (pRes['name'] as String?)?.trim();
                  final uname = (pRes['username'] as String?)?.trim();
                  if (name != null && name.isNotEmpty) {
                    senderName = name;
                  } else if (uname != null && uname.isNotEmpty) {
                    senderName = uname;
                  }
                }
              } catch (_) {}

              await NotificationService.instance.showFriendRequestNotification(
                senderName: senderName,
                requestId: reqId,
              );
            }
          }
      } catch (e) {
        debugPrint('[BackgroundSync] Error checking friend requests: $e');
      }

      // 2. Check for unviewed direct snaps
      try {
        final unviewedSnaps = await client
            .from('snap_recipients')
            .select(
                'snap_id, viewed_at, snap:snaps!inner(id, sender_id, activity_type)')
            .eq('recipient_id', userId);

        for (final row in unviewedSnaps) {
            final rMap = Map<String, dynamic>.from(row as Map);
            if (rMap['viewed_at'] != null) continue; // Already viewed

            final snapId = rMap['snap_id'] as String;
            final snapKey = 'snap_$snapId';

            if (!notifiedIds.contains(snapKey)) {
              notifiedIds.add(snapKey);
              final snapData = Map<String, dynamic>.from(rMap['snap'] as Map);
              final senderId = snapData['sender_id'] as String;
              final actType = snapData['activity_type'] as String?;
              String senderName = 'A friend';

              try {
                final pRes = await client
                    .from('profiles')
                    .select('name, username')
                    .eq('id', senderId)
                    .maybeSingle();
                if (pRes != null) {
                  final name = (pRes['name'] as String?)?.trim();
                  final uname = (pRes['username'] as String?)?.trim();
                  if (name != null && name.isNotEmpty) {
                    senderName = name;
                  } else if (uname != null && uname.isNotEmpty) {
                    senderName = uname;
                  }
                }
              } catch (_) {}

              await NotificationService.instance.showSnapNotification(
                senderName: senderName,
                snapId: snapId,
                activityType: actType,
              );
            }
          }
      } catch (e) {
        debugPrint('[BackgroundSync] Error checking snaps: $e');
      }

      // Keep set bounded to last 200 items to prevent unbounded list
      final list = notifiedIds.toList();
      if (list.length > 200) {
        list.removeRange(0, list.length - 200);
      }
      await prefs.setStringList('notified_social_ids', list);

      return true;
    } catch (e) {
      debugPrint('[BackgroundSync] executeTask exception: $e');
      return true;
    }
  });
}

/// Service managing background social notifications and synchronization.
class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  static const String periodicTaskName = 'vyayama-social-periodic';
  static const String quickTaskPrefix = 'vyayama-social-quick-';
  static const String taskIdentifier = 'social_sync_task';

  bool _initialized = false;

  /// Whether background work is supported on the current platform.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initializes the WorkManager and schedules the recurring background task.
  Future<void> initialize() async {
    if (!isSupportedPlatform || _initialized) return;

    try {
      await Workmanager().initialize(callbackDispatcher);

      // Register periodic background sync (every 15 min - Android system minimum)
      await Workmanager().registerPeriodicTask(
        periodicTaskName,
        taskIdentifier,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );

      _initialized = true;
    } catch (e) {
      debugPrint('[BackgroundSyncService] init error: $e');
    }
  }

  /// Sets the currently active user ID in SharedPreferences so the background worker knows who to monitor.
  Future<void> syncCurrentUserId(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId == null || userId.isEmpty) {
        await prefs.remove('last_signed_in_user_id');
      } else {
        await prefs.setString('last_signed_in_user_id', userId);
      }
    } catch (e) {
      debugPrint('[BackgroundSyncService] syncCurrentUserId error: $e');
    }
  }

  /// Records an already notified ID so background tasks won't produce duplicate alerts.
  Future<void> markAsNotified(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('notified_social_ids') ?? [];
      if (!list.contains(id)) {
        list.add(id);
        if (list.length > 200) {
          list.removeRange(0, list.length - 200);
        }
        await prefs.setStringList('notified_social_ids', list);
      }
    } catch (_) {}
  }

  /// When the app enters paused/background or detached state, register quick one-off tasks
  /// so immediate checks occur within seconds or minutes after the app is closed.
  Future<void> scheduleOnAppClosed() async {
    if (!isSupportedPlatform || !Env.isSupabaseConfigured) return;

    try {
      // 15 seconds after app closed
      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}1',
        taskIdentifier,
        initialDelay: const Duration(seconds: 15),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      // 60 seconds after app closed
      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}2',
        taskIdentifier,
        initialDelay: const Duration(seconds: 60),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      // 3 minutes after app closed
      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}3',
        taskIdentifier,
        initialDelay: const Duration(minutes: 3),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      // 7 minutes after app closed
      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}4',
        taskIdentifier,
        initialDelay: const Duration(minutes: 7),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('[BackgroundSyncService] scheduleOnAppClosed error: $e');
    }
  }
}
