import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/app.dart';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/services/shared_prefs_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `.env` is optional so the app still runs with mock repositories.
  await dotenv.load(fileName: '.env', isOptional: true);

  // Supabase is only initialised when real keys are present.
  if (Env.isSupabaseConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VyayamaApp(),
    ),
  );
}
