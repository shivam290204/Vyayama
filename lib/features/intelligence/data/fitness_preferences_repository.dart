import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/intelligence/domain/models/user_fitness_preferences.dart';

/// Contract for reading and storing user fitness preferences.
abstract interface class FitnessPreferencesRepository {
  /// Loads saved preferences for [userId], or default values if none exist yet.
  Future<UserFitnessPreferences> getPreferences(String userId);

  /// Saves or updates preferences for [preferences.userId].
  Future<void> savePreferences(UserFitnessPreferences preferences);
}

/// SharedPreferences-backed local-first implementation of [FitnessPreferencesRepository].
///
/// Features:
/// 1. Namespaced by user ID: `user_fitness_preferences_$uid`.
/// 2. Isolated across user accounts on the same device.
/// 3. Completely offline, zero network reliance.
/// 4. Graceful fallback defaults for legacy or new users.
class SharedPrefsFitnessPreferencesRepository
    implements FitnessPreferencesRepository {
  SharedPrefsFitnessPreferencesRepository({SharedPreferences? prefs})
      : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _asyncPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  String _key(String userId) => 'user_fitness_preferences_$userId';

  @override
  Future<UserFitnessPreferences> getPreferences(String userId) async {
    final cleanUid = userId.trim().isEmpty ? 'local_user' : userId.trim();
    try {
      final p = await _asyncPrefs;
      final raw = p.getString(_key(cleanUid));
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          return UserFitnessPreferences.fromJson(map);
        } else if (map is Map) {
          return UserFitnessPreferences.fromJson(Map<String, dynamic>.from(map));
        }
      }
    } catch (e) {
      debugPrint('[FitnessPreferencesRepo] Error loading preferences: $e');
    }
    return UserFitnessPreferences.defaults(userId: cleanUid);
  }

  @override
  Future<void> savePreferences(UserFitnessPreferences preferences) async {
    final cleanUid =
        preferences.userId.trim().isEmpty ? 'local_user' : preferences.userId.trim();
    try {
      final p = await _asyncPrefs;
      final toSave = preferences.copyWith(
        userId: cleanUid,
        updatedAt: DateTime.now(),
      );
      await p.setString(_key(cleanUid), jsonEncode(toSave.toJson()));
    } catch (e) {
      debugPrint('[FitnessPreferencesRepo] Error saving preferences: $e');
    }
  }
}

