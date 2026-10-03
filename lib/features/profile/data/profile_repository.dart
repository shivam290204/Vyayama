import 'package:fitbuddy/features/profile/data/profile.dart';

/// Reads and writes the signed-in user's profile.
/// Antigravity replaces the mock with a Supabase implementation.
abstract class ProfileRepository {
  /// Returns the profile row, or null if none exists yet.
  Future<Profile?> fetchProfile(String userId);

  /// Inserts or updates the profile and returns the saved row.
  Future<Profile> upsertProfile(Profile profile);
}
