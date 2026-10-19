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
    try {
      return await ref.read(profileRepositoryProvider).fetchProfile(userId);
    } catch (e) {
      debugPrint('[CurrentProfileNotifier] fetchProfile error: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('cached_profile_$userId');
        if (raw != null && raw.isNotEmpty) {
          return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
        final wasCompleted =
            prefs.getBool('onboarding_completed_$userId') ?? true;
        return Profile(id: userId, onboardingCompleted: wasCompleted);
      } catch (_) {}
      return Profile(id: userId, onboardingCompleted: true);
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
