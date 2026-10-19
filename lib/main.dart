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
  await dotenv.load(fileName: '.env', isOptional: true);

  // Supabase is only initialised when real keys are present.
  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  // Initialize native local notification channels and timezones early
  await NotificationService.instance.initialize();

  // Initialize background sync service for social notifications when app is closed
  await BackgroundSyncService.instance.initialize();

  final prefs = await SharedPreferences.getInstance();

  if (Env.isSupabaseConfigured) {
    await BackgroundSyncService.instance.syncCurrentUserId(
      Supabase.instance.client.auth.currentUser?.id,
    );
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VyayamaApp(),
    ),
  );
}
