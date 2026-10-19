import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/profile/data/mock_profile_repository.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';
import 'package:fitbuddy/features/profile/data/supabase_profile_repository.dart';

/// Provides [SupabaseProfileRepository] when configured, falling back to mock.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    return SupabaseProfileRepository();
  }
  return MockProfileRepository();
});

/// The signed-in user's profile (null when logged out).
class CurrentProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // Watch only the id so token refreshes do not reload the profile.
    final userId = ref.watch(
      authStateProvider.select((auth) => auth.valueOrNull?.id),
    );
    if (userId == null) return null;

    // 1. Read locally cached profile (< 1ms)
    Profile? cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_profile_$userId');
      if (raw != null && raw.isNotEmpty) {
        cached = Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
      final wasCompleted =
          prefs.getBool('onboarding_completed_$userId') ?? true;
      cached ??= Profile(id: userId, onboardingCompleted: wasCompleted);
    } catch (_) {
      cached = Profile(id: userId, onboardingCompleted: true);
    }

    // 2. Attempt remote fetch with a 1.5-second timeout so offline startup NEVER hangs
    try {
      final remote = await ref
          .read(profileRepositoryProvider)
          .fetchProfile(userId)
          .timeout(const Duration(milliseconds: 1500));
      return remote ?? cached;
    } catch (e) {
      debugPrint('[CurrentProfileNotifier] Offline or timeout, using cached profile: $e');
      return cached;
    }
  }

  /// Saves [profile] and updates the cached value without a loading flash.
  Future<Profile> save(Profile profile) async {
    final saved = await ref.read(profileRepositoryProvider).upsertProfile(profile);
    state = AsyncData(saved);
    return saved;
  }
}

final currentProfileProvider =
    AsyncNotifierProvider<CurrentProfileNotifier, Profile?>(
  CurrentProfileNotifier.new,
);
