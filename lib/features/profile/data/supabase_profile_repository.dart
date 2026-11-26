import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [ProfileRepository] backed by the `profiles` table.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({
    SupabaseClient? client,
    SharedPreferences? prefs,
    String? currentUserIdOverride,
  })  : _client = client ?? Supabase.instance.client,
        _prefs = prefs,
        _currentUserIdOverride = currentUserIdOverride;

  final SupabaseClient _client;
  final SharedPreferences? _prefs;
  final String? _currentUserIdOverride;

  Future<SharedPreferences> get _effectivePrefs async =>
      _prefs ?? await SharedPreferences.getInstance();

  String? get currentUserId =>
      _currentUserIdOverride ?? _client.auth.currentUser?.id;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    try {
      final res = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (res == null) return null;
      final profile = Profile.fromJson(Map<String, dynamic>.from(res));
      try {
        final prefs = await _effectivePrefs;
        await prefs.setString('cached_profile_$userId', jsonEncode(profile.toJson()));
        if (profile.onboardingCompleted) {
          await prefs.setBool('onboarding_completed_$userId', true);
        }
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
      final prefs = await _effectivePrefs;
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
    // 1. Recover auth session if needed
    if (currentUserId == null && _client.auth.currentSession == null) {
      try {
        final prefs = await _effectivePrefs;
        final refreshToken = prefs.getString('cached_auth_refresh_token');
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _client.auth.recoverSession(refreshToken);
        }
      } catch (_) {}
    }

    final userId = currentUserId;
    if (userId == null || userId.isEmpty) {
      throw const ProfileUpdateException(
        'Not authenticated. Please sign in again.',
      );
    }

    // 2. Verify authenticated user ID matches the profile being edited
    if (profile.id.isNotEmpty && profile.id != userId) {
      throw const ProfileUpdateException(
        'Unauthorized: Cannot update another user\'s profile.',
      );
    }

    // 3. Construct sanitized profile
    final sanitizedProfile = Profile(
      id: userId,
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

    // 4. Prepare update payload excluding protected/immutable columns (id, invite_token, created_at)
    final data = sanitizedProfile.toJson();
    data.remove('id');
    data.remove('invite_token');
    data.remove('created_at');

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

    // 5. Execute standard UPDATE on the user's existing row
    try {
      final res = await _client
          .from('profiles')
          .update(data)
          .eq('id', userId)
          .select()
          .single()
          .timeout(const Duration(seconds: 4));

      final saved = Profile.fromJson(Map<String, dynamic>.from(res));

      // Persist confirmed saved profile to local cache
      try {
        final prefs = await _effectivePrefs;
        await prefs.setString(
          'cached_profile_${saved.id}',
          jsonEncode(saved.toJson()),
        );
        if (saved.onboardingCompleted) {
          await prefs.setBool('onboarding_completed_${saved.id}', true);
        }
      } catch (_) {}

      return saved;
    } on PostgrestException catch (e) {
      debugPrint('[SupabaseProfileRepository] PostgrestException on update: $e');
      if (e.code == 'PGRST116' || e.message.contains('0 rows')) {
        throw ProfileUpdateException(
          'Profile row not found for user $userId. Please contact support.',
          cause: e,
        );
      }
      if (e.code == '42501' || e.message.toLowerCase().contains('row-level security')) {
        throw ProfileUpdateException(
          'Permission denied updating profile. RLS policy violation.',
          cause: e,
        );
      }
      throw ProfileUpdateException(
        'Database update failed: ${e.message}',
        cause: e,
      );
    } catch (e) {
      if (e is ProfileUpdateException) rethrow;
      debugPrint('[SupabaseProfileRepository] Network/remote error on update: $e');

      // Preserve offline cache behavior: save draft locally
      try {
        final prefs = await _effectivePrefs;
        await prefs.setString(
          'cached_profile_$userId',
          jsonEncode(sanitizedProfile.toJson()),
        );
        if (sanitizedProfile.onboardingCompleted) {
          await prefs.setBool('onboarding_completed_$userId', true);
        }
      } catch (_) {}

      throw ProfileUpdateException(
        'Profile saved locally (offline). Changes are not synced to the cloud.',
        isLocalOnly: true,
        cause: e,
      );
    }
  }
}
