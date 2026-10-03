import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/profile/data/mock_profile_repository.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';

/// Swap this for a Supabase-backed repository later.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => MockProfileRepository(),
);

/// The signed-in user's profile (null when logged out).
class CurrentProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // Watch only the id so token refreshes do not reload the profile.
    final userId = ref.watch(
      authStateProvider.select((auth) => auth.valueOrNull?.id),
    );
    if (userId == null) return null;
    return ref.read(profileRepositoryProvider).fetchProfile(userId);
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
