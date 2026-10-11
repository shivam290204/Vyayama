import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [ProfileRepository] backed by the `profiles` table.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (res == null) return null;
      return Profile.fromJson(Map<String, dynamic>.from(res));
    } on PostgrestException catch (e) {
      // 401 Unauthorized or invalid API key: the auth session or project key is invalid.
      // Auto-sign out so the user is cleanly redirected to login instead of stuck on splash.
      if (e.code == '401' ||
          e.message.toLowerCase().contains('api key') ||
          e.message.toLowerCase().contains('jwt') ||
          e.message.toLowerCase().contains('unauthorized')) {
        try {
          await _client.auth.signOut();
        } catch (_) {}
        return null;
      }
      rethrow;
    } catch (e) {
      // Re-throw or handle network/auth errors as needed
      rethrow;
    }
  }

  @override
  Future<Profile> upsertProfile(Profile profile) async {
    final data = profile.toJson();

    // Sanitize fields against Postgres table check constraints
    final username = profile.username?.trim();
    if (username == null || username.isEmpty) {
      data['username'] = null;
    } else {
      data['username'] = username.toLowerCase();
    }

    if (profile.gender != null &&
        !ProfileOptions.genders.contains(profile.gender)) {
      data['gender'] = null;
    }

    if (profile.goal != null && !ProfileOptions.goals.contains(profile.goal)) {
      data['goal'] = null;
    }

    final res = await _client
        .from('profiles')
        .upsert(data, onConflict: 'id')
        .select()
        .single();

    return Profile.fromJson(Map<String, dynamic>.from(res));
  }
}
