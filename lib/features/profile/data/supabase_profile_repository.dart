import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      final wasCompleted = prefs.getBool('onboarding_completed_$userId') ?? true;
      final lastId = prefs.getString('last_signed_in_user_id');
      if (lastId == userId) {
        return Profile(
          id: userId,
          onboardingCompleted: wasCompleted,
        );
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<Profile> upsertProfile(Profile profile) async {
    final effectiveId = _client.auth.currentUser?.id ?? profile.id;
    final sanitizedProfile = effectiveId == profile.id
        ? profile
        : Profile(
            id: effectiveId,
            name: profile.name,
            age: profile.age,
            gender: profile.gender,
            weightKg: profile.weightKg,
            heightCm: profile.heightCm,
            goal: profile.goal,
            fitnessLevel: profile.fitnessLevel,
            wakeTime: profile.wakeTime,
            sleepTime: profile.sleepTime,
            workStart: profile.workStart,
            workEnd: profile.workEnd,
            username: profile.username,
            avatarUrl: profile.avatarUrl,
            timezone: profile.timezone,
            onboardingCompleted: profile.onboardingCompleted,
          );

    // 1. Always persist to local cache FIRST (<1ms) so offline changes
    // are immediately stored and never lost due to connection drops.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_profile_$effectiveId',
        jsonEncode(sanitizedProfile.toJson()),
      );
      if (sanitizedProfile.onboardingCompleted) {
        await prefs.setBool('onboarding_completed_$effectiveId', true);
      }
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Local cache save error: $e');
    }

    // 2. Prepare payload and strictly sanitize fields to prevent database constraint failures
    final data = sanitizedProfile.toJson();
    data['id'] = effectiveId;

    // Sanitize username (alphanumeric + underscore, 3 to 20 chars)
    final username = sanitizedProfile.username?.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (username == null || username.isEmpty) {
      data['username'] = null;
    } else {
      final validRegex = RegExp(r'^[a-z0-9_]{3,20}$');
      if (validRegex.hasMatch(username)) {
        data['username'] = username;
      } else {
        final stripped = username.replaceAll(RegExp(r'[^a-z0-9_]'), '');
        data['username'] = (stripped.length >= 3 && stripped.length <= 20) ? stripped : null;
      }
    }

    // Sanitize gender
    if (sanitizedProfile.gender != null &&
        !ProfileOptions.genders.contains(sanitizedProfile.gender)) {
      data['gender'] = null;
    }

    // Sanitize goal
    if (sanitizedProfile.goal != null &&
        !ProfileOptions.goals.contains(sanitizedProfile.goal)) {
      data['goal'] = null;
    }

    // Sanitize age (between 13 and 100)
    if (sanitizedProfile.age != null &&
        (sanitizedProfile.age! < 13 || sanitizedProfile.age! > 100)) {
      data['age'] = null;
    }

    // Sanitize weight & height
    if (sanitizedProfile.weightKg != null &&
        (sanitizedProfile.weightKg! <= 0 || sanitizedProfile.weightKg! > 500)) {
      data['weight_kg'] = null;
    }
    if (sanitizedProfile.heightCm != null &&
        (sanitizedProfile.heightCm! <= 0 || sanitizedProfile.heightCm! > 300)) {
      data['height_cm'] = null;
    }

    // 3. Attempt remote upsert to Supabase
    try {
      // If auth session is missing, attempt to recover it from cached refresh token
      if (_client.auth.currentSession == null) {
        final prefs = await SharedPreferences.getInstance();
        final refreshToken = prefs.getString('cached_auth_refresh_token');
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _client.auth.recoverSession(refreshToken);
        }
      }

      final res = await _client
          .from('profiles')
          .upsert(data, onConflict: 'id')
          .select()
          .single()
          .timeout(const Duration(seconds: 4));

      final saved = Profile.fromJson(Map<String, dynamic>.from(res));
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'cached_profile_${saved.id}',
          jsonEncode(saved.toJson()),
        );
      } catch (_) {}
      return saved;
    } catch (e) {
      debugPrint('[SupabaseProfileRepository] Remote upsert failed (profile saved locally): $e');
      // In offline-first architecture, return the locally saved profile so the user
      // can continue editing and using their profile without interruption.
      return sanitizedProfile;
    }
  }
}
