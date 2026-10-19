import 'dart:convert';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      final profile = Profile.fromJson(Map<String, dynamic>.from(res));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_profile_$userId', jsonEncode(profile.toJson()));
      } catch (_) {}
      return profile;
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
      final cached = await _getCachedProfile(userId);
      if (cached != null) return cached;
      rethrow;
    } catch (e) {
      final cached = await _getCachedProfile(userId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<Profile?> _getCachedProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_profile_$userId');
      if (raw != null && raw.isNotEmpty) {
        return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
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

    final saved = Profile.fromJson(Map<String, dynamic>.from(res));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_profile_${saved.id}', jsonEncode(saved.toJson()));
    } catch (_) {}
    return saved;
  }
}
