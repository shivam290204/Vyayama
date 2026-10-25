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

  // Initialize native local notification channels and timezones early
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService.initialize error: $e');
  }

  // Initialize background sync service for social notifications when app is closed
  try {
    await BackgroundSyncService.instance.initialize();
  } catch (e) {
    debugPrint('BackgroundSyncService.initialize error: $e');
  }

  // Initialize Firebase Cloud Messaging for instant push notifications
  try {
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('PushNotificationService.initialize error: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  if (Env.isSupabaseConfigured) {
    try {
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      if (currentUid != null && currentUid.isNotEmpty) {
        await BackgroundSyncService.instance.syncCurrentUserId(currentUid);
        await PushNotificationService.instance.syncCurrentUserId(currentUid);
      }
    } catch (e) {
      debugPrint('BackgroundSyncService.syncCurrentUserId error: $e');
    }
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VyayamaApp(),
    ),
  );
}
