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
import 'package:fitbuddy/core/services/shared_prefs_provider.dart';

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

  // Supabase is only initialised when real keys are present.
  if (Env.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
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

  final prefs = await SharedPreferences.getInstance();

  if (Env.isSupabaseConfigured) {
    try {
      await BackgroundSyncService.instance.syncCurrentUserId(
        Supabase.instance.client.auth.currentUser?.id,
      );
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
