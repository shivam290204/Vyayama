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
      try {
        await dotenv.load(fileName: '.env', isOptional: true);
      } catch (_) {}

      try {
        await NotificationService.instance.initialize();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      var userId = prefs.getString('last_signed_in_user_id');

      final supabaseUrl = Env.isSupabaseConfigured
          ? Env.supabaseUrl
          : (prefs.getString('cached_supabase_url') ?? '');
      final supabaseAnonKey = Env.isSupabaseConfigured
          ? Env.supabaseAnonKey
          : (prefs.getString('cached_supabase_anon_key') ?? '');

      if (!supabaseUrl.startsWith('http') || supabaseAnonKey.isEmpty) {
        debugPrint('[BackgroundSync] Supabase not configured in background');
        return true;
      }

      final accessToken = prefs.getString('cached_auth_access_token');
      final refreshToken = prefs.getString('cached_auth_refresh_token');

      // Initialize Supabase in this background isolate if needed
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          publishableKey: supabaseAnonKey,
        );
      } catch (_) {}

      // Create an authenticated client with user's access token
      final client = SupabaseClient(
        supabaseUrl,
        supabaseAnonKey,
        headers: {
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        },
      );

      if (accessToken != null && accessToken.isNotEmpty) {
        client.rest.headers['Authorization'] = 'Bearer $accessToken';
      }

      // Refresh / establish active authenticated session if we have a refresh token
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final authRes = await client.auth.setSession(refreshToken);
          if (authRes.user != null) {
            userId = authRes.user!.id;
            if (authRes.session?.accessToken != null) {
              final newTok = authRes.session!.accessToken;
              client.rest.headers['Authorization'] = 'Bearer $newTok';
              await prefs.setString('cached_auth_access_token', newTok);
            }
            if (authRes.session?.refreshToken != null) {
              await prefs.setString(
                  'cached_auth_refresh_token', authRes.session!.refreshToken!);
            }
          }
        } catch (e) {
          debugPrint('[BackgroundSync] Session refresh notice: $e');
        }
      }

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

      // 1. Check for pending incoming friend requests (try RPC first, fallback to table query)
      try {
        bool handledByRpc = false;
        try {
          final rpcRes = await client.rpc('get_my_friend_requests');
          if (rpcRes is List) {
            handledByRpc = true;
            for (final row in rpcRes) {
              final rMap = Map<String, dynamic>.from(row as Map);
              final incoming = rMap['is_incoming'] == true ||
                  rMap['addressee_id'] == userId;
              final status = rMap['status'] as String?;
              if (!incoming || status != 'pending') continue;

              final reqId = (rMap['id'] ?? rMap['friendship_id']) as String;
              final reqKey = 'req_$reqId';
              if (!notifiedIds.contains(reqKey)) {
                notifiedIds.add(reqKey);
                final rawName = (rMap['other_name'] as String?)?.trim();
                final rawUname = (rMap['other_username'] as String?)?.trim();
                final senderName = (rawName != null &&
                        rawName.isNotEmpty &&
                        rawName != 'Pending Friend' &&
                        rawName != 'Athlete')
                    ? rawName
                    : ((rawUname != null && rawUname.isNotEmpty)
                        ? rawUname
                        : (rawName != null && rawName.isNotEmpty ? rawName : 'A friend'));
                await NotificationService.instance.showFriendRequestNotification(
                  senderName: senderName,
                  requestId: reqId,
                );
              }
            }
          }
        } catch (_) {}

        if (!handledByRpc) {
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
                // Try find_profile_by_identifier RPC first
                final rpc = await client.rpc(
                  'find_profile_by_identifier',
                  params: {'p_query': requesterId},
                );
                if (rpc is List && rpc.isNotEmpty) {
                  final row = Map<String, dynamic>.from(rpc.first as Map);
                  final name = (row['name'] as String?)?.trim();
                  final uname = (row['username'] as String?)?.trim();
                  if (name != null &&
                      name.isNotEmpty &&
                      name != 'Athlete' &&
                      name != 'Pending Friend') {
                    senderName = name;
                  } else if (uname != null && uname.isNotEmpty) {
                    senderName = uname;
                  }
                } else {
                  final pRes = await client
                      .from('profiles')
                      .select('name, username')
                      .eq('id', requesterId)
                      .maybeSingle();
                  if (pRes != null) {
                    final name = (pRes['name'] as String?)?.trim();
                    final uname = (pRes['username'] as String?)?.trim();
                    if (name != null &&
                        name.isNotEmpty &&
                        name != 'Athlete' &&
                        name != 'Pending Friend') {
                      senderName = name;
                    } else if (uname != null && uname.isNotEmpty) {
                      senderName = uname;
                    }
                  }
                }
              } catch (_) {}

              await NotificationService.instance.showFriendRequestNotification(
                senderName: senderName,
                requestId: reqId,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[BackgroundSync] Error checking friend requests: $e');
      }

      // 2. Check for unviewed direct snaps (try RPC first, fallback to table query)
      try {
        bool handledByRpc = false;
        try {
          final rpcSnaps = await client.rpc('get_my_inbox_snaps');
          if (rpcSnaps is List) {
            handledByRpc = true;
            for (final row in rpcSnaps) {
              final rMap = Map<String, dynamic>.from(row as Map);
              if (rMap['viewed_at'] != null) continue;

              final snapId = (rMap['id'] ?? rMap['snap_id']) as String;
              final snapKey = 'snap_$snapId';

              if (!notifiedIds.contains(snapKey)) {
                notifiedIds.add(snapKey);
                final rawName = (rMap['sender_name'] as String?)?.trim();
                final rawUname = (rMap['sender_username'] as String?)?.trim();
                final senderName = (rawName != null && rawName.isNotEmpty)
                    ? rawName
                    : ((rawUname != null && rawUname.isNotEmpty)
                        ? rawUname
                        : 'A friend');
                final actType = rMap['activity_type'] as String?;

                await NotificationService.instance.showSnapNotification(
                  senderName: senderName,
                  snapId: snapId,
                  activityType: actType,
                );
              }
            }
          }
        } catch (_) {}

        if (!handledByRpc) {
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
      if (Env.isSupabaseConfigured) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_supabase_url', Env.supabaseUrl);
          await prefs.setString('cached_supabase_anon_key', Env.supabaseAnonKey);
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            await prefs.setString('cached_auth_access_token', session.accessToken);
            if (session.refreshToken != null) {
              await prefs.setString('cached_auth_refresh_token', session.refreshToken!);
            }
          }
          final uid = session?.user.id ?? Supabase.instance.client.auth.currentUser?.id;
          if (uid != null && uid.isNotEmpty && uid != 'u-me') {
            await prefs.setString('last_signed_in_user_id', uid);
          }
        } catch (_) {}
      }

      await Workmanager().initialize(callbackDispatcher);

      // Register periodic background sync (every 15 min - Android system minimum)
      await Workmanager().registerPeriodicTask(
        periodicTaskName,
        taskIdentifier,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
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
        await prefs.remove('cached_auth_access_token');
        await prefs.remove('cached_auth_refresh_token');
      } else {
        await prefs.setString('last_signed_in_user_id', userId);
        if (Env.isSupabaseConfigured) {
          await prefs.setString('cached_supabase_url', Env.supabaseUrl);
          await prefs.setString('cached_supabase_anon_key', Env.supabaseAnonKey);
          try {
            final session = Supabase.instance.client.auth.currentSession;
            if (session != null) {
              await prefs.setString('cached_auth_access_token', session.accessToken);
              if (session.refreshToken != null) {
                await prefs.setString('cached_auth_refresh_token', session.refreshToken!);
              }
            }
          } catch (_) {}
        }
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
    if (!isSupportedPlatform) return;

    try {
      if (Env.isSupabaseConfigured) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_supabase_url', Env.supabaseUrl);
          await prefs.setString('cached_supabase_anon_key', Env.supabaseAnonKey);
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            await prefs.setString('cached_auth_access_token', session.accessToken);
            if (session.refreshToken != null) {
              await prefs.setString('cached_auth_refresh_token', session.refreshToken!);
            }
          }
          final uid = session?.user.id ?? Supabase.instance.client.auth.currentUser?.id;
          if (uid != null && uid.isNotEmpty && uid != 'u-me') {
            await prefs.setString('last_signed_in_user_id', uid);
          }
        } catch (_) {}
      }

      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}1',
        taskIdentifier,
        initialDelay: const Duration(seconds: 15),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}2',
        taskIdentifier,
        initialDelay: const Duration(seconds: 45),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}3',
        taskIdentifier,
        initialDelay: const Duration(minutes: 2),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}4',
        taskIdentifier,
        initialDelay: const Duration(minutes: 5),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      await Workmanager().registerOneOffTask(
        '${quickTaskPrefix}5',
        taskIdentifier,
        initialDelay: const Duration(minutes: 10),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('[BackgroundSyncService] scheduleOnAppClosed error: $e');
    }
  }
}
