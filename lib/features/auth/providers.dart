import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:fitbuddy/features/auth/data/mock_auth_repository.dart';
import 'package:fitbuddy/features/auth/data/supabase_auth_repository.dart';

/// Swap this for a Supabase-backed repository later.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    return SupabaseAuthRepository();
  } else {
    if (kReleaseMode) {
      throw StateError(
        'Critical configuration error: Supabase is not configured in release mode. '
        'Provide SUPABASE_URL and SUPABASE_ANON_KEY at build time via --dart-define or --dart-define-from-file.',
      );
    }
    final repository = MockAuthRepository();
    ref.onDispose(repository.dispose);
    return repository;
  }
});

/// Current auth user (null = signed out). Drives the router redirect.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
