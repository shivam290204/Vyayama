import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/app.dart';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/services/background_sync_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/services/push_notification_service.dart';
import 'package:fitbuddy/core/services/secure_auth_storage.dart';
import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/core/widgets/app_not_configured_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard against unhandled asynchronous exceptions crashing the process
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher error caught: $error\n$stack');
    return true; // handled, prevents app from closing
  };

  // `.env` is optional so the app still runs with mock repositories.
  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (e) {
    debugPrint('dotenv.load error: $e');
  }

  // In release builds, if Supabase configuration is missing, show a clean
  // configuration required screen instead of crashing.
  if (kReleaseMode && !Env.isSupabaseConfigured) {
    runApp(const AppNotConfiguredApp());
    return;
  }

  // Supabase is only initialised when real keys are present.
  if (Env.isSupabaseConfigured) {
    try {
      final sessionKey =
          'sb-${Uri.parse(Env.supabaseUrl).host.split(".").first}-auth-token';
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage:
              SupabaseSecureLocalStorage(persistSessionKey: sessionKey),
          pkceAsyncStorage: SupabaseSecureGotrueAsyncStorage(),
        ),
      );
    } catch (e) {
      debugPrint('Supabase.initialize error: $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();

  String? initialUid;
  if (Env.isSupabaseConfigured) {
    try {
      initialUid = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VyayamaApp(),
    ),
  );

  // Initialize heavy native & network services after first frame is queued
  // so app startup is never stalled waiting on timezone DB, WorkManager, or FCM.
  unawaited(_initializeDeferredServices(initialUid));
}

Future<void> _initializeDeferredServices(String? currentUid) async {
  await Future.wait([
    NotificationService.instance.initialize().catchError((Object e) {
      debugPrint('NotificationService.initialize error: $e');
    }),
    BackgroundSyncService.instance.initialize().catchError((Object e) {
      debugPrint('BackgroundSyncService.initialize error: $e');
    }),
    PushNotificationService.instance.initialize().catchError((Object e) {
      debugPrint('PushNotificationService.initialize error: $e');
    }),
  ]);

  if (Env.isSupabaseConfigured && currentUid != null && currentUid.isNotEmpty) {
    unawaited(
      BackgroundSyncService.instance.syncCurrentUserId(currentUid).catchError(
        (Object e) {
          debugPrint('BackgroundSyncService.syncCurrentUserId error: $e');
        },
      ),
    );
    unawaited(
      PushNotificationService.instance.syncCurrentUserId(currentUid).catchError(
        (Object e) {
          debugPrint('PushNotificationService.syncCurrentUserId error: $e');
        },
      ),
    );
  }
}
