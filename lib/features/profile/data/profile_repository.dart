import 'package:fitbuddy/features/profile/data/profile.dart';

/// Thrown when updating a profile fails.
class ProfileUpdateException implements Exception {
  const ProfileUpdateException(
    this.message, {
    this.isLocalOnly = false,
    this.cause,
  });

  final String message;
  final bool isLocalOnly;
  final Object? cause;

  @override
  String toString() => message;
}

/// Reads and writes the signed-in user's profile.
/// Antigravity replaces the mock with a Supabase implementation.
abstract class ProfileRepository {
  /// Returns the profile row, or null if none exists yet.
  Future<Profile?> fetchProfile(String userId);

  /// Updates the profile and returns the saved row.
  Future<Profile> upsertProfile(Profile profile);
}
