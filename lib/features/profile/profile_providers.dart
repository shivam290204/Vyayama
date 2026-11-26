import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/profile/data/bmi_history_repository.dart';
import 'package:fitbuddy/features/profile/data/bmi_record.dart';
import 'package:fitbuddy/features/profile/data/mock_profile_repository.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';
import 'package:fitbuddy/features/profile/data/supabase_profile_repository.dart';
import 'package:fitbuddy/features/profile/logic/bmi_calculator.dart';

/// Provides [SupabaseProfileRepository] when configured, falling back to mock.
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    try {
      return SupabaseProfileRepository();
    } catch (e) {
      debugPrint('[profileRepositoryProvider] Fallback: $e');
    }
  }
  return MockProfileRepository();
});

/// The signed-in user's profile (null when logged out).
class CurrentProfileNotifier extends AsyncNotifier<Profile?> {
  bool _disposed = false;

  @override
  Future<Profile?> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    // Watch only the id so token refreshes do not reload the profile.
    final userId = ref.watch(
      authStateProvider.select((auth) => auth.valueOrNull?.id),
    );
    if (userId == null) return null;

    // 1. Read locally cached profile (< 1ms)
    Profile? cached;
    var hasRealCachedProfile = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_profile_$userId');
      if (raw != null && raw.isNotEmpty) {
        cached = Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        hasRealCachedProfile = true;
      }
      final wasCompleted =
          prefs.getBool('onboarding_completed_$userId') ?? true;
      cached ??= Profile(id: userId, onboardingCompleted: wasCompleted);
    } catch (_) {
      cached = Profile(id: userId, onboardingCompleted: true);
    }

    // Returning users with a full cached profile should enter immediately;
    // refresh remotely in the background instead of stalling on SplashScreen.
    if (hasRealCachedProfile) {
      unawaited(_refreshRemoteInBackground(userId, cached));
      return cached;
    }

    // 2. First-time / uncached startup: attempt remote fetch with short timeout
    try {
      final remote = await ref
          .read(profileRepositoryProvider)
          .fetchProfile(userId)
          .timeout(const Duration(seconds: 4));
      return remote ?? cached;
    } catch (e) {
      debugPrint(
          '[CurrentProfileNotifier] Offline or timeout, using cached profile: $e');
      return cached;
    }
  }

  Future<void> _refreshRemoteInBackground(String userId, Profile? cached) async {
    try {
      final remote = await ref
          .read(profileRepositoryProvider)
          .fetchProfile(userId)
          .timeout(const Duration(seconds: 4));
      if (_disposed || remote == null) return;
      if (jsonEncode(remote.toJson()) !=
          (cached != null ? jsonEncode(cached.toJson()) : null)) {
        state = AsyncData(remote);
      }
    } catch (_) {}
  }

  /// Saves [profile] and updates the cached value without a loading flash.
  Future<Profile> save(Profile profile) async {
    try {
      final saved = await ref.read(profileRepositoryProvider).upsertProfile(profile);
      state = AsyncData(saved);
      return saved;
    } on ProfileUpdateException catch (e) {
      if (e.isLocalOnly) {
        state = AsyncData(profile);
      }
      rethrow;
    } catch (e) {
      debugPrint('[CurrentProfileNotifier] save error: $e');
      rethrow;
    }
  }
}

final currentProfileProvider =
    AsyncNotifierProvider<CurrentProfileNotifier, Profile?>(
  CurrentProfileNotifier.new,
);

/// Singleton repository for historical BMI and weight records.
final bmiHistoryRepositoryProvider = Provider<BmiHistoryRepository>((ref) {
  return BmiHistoryRepository();
});

/// Pure reactive BMI computation derived immediately from current profile.
/// Recalculates automatically whenever weight or height changes.
final currentBmiProvider = Provider<BmiResult?>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return null;
  return BmiCalculator.calculate(
    weightKg: profile.weightKg,
    heightCm: profile.heightCm,
    age: profile.age,
  );
});

/// Notifier managing historical BMI records for the signed-in user.
class BmiHistoryNotifier extends AsyncNotifier<List<BmiRecord>> {
  @override
  Future<List<BmiRecord>> build() async {
    final userId = ref.watch(
      authStateProvider.select((auth) => auth.valueOrNull?.id),
    );
    if (userId == null) return [];
    final repo = ref.watch(bmiHistoryRepositoryProvider);
    return repo.getHistory(userId);
  }

  /// Logs a new weight/height entry, creates a timestamped BmiRecord,
  /// and updates the user's active Profile.
  Future<void> recordMeasurement({
    required double weightKg,
    double? heightCm,
    String? notes,
  }) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;

    final profile = ref.read(currentProfileProvider).valueOrNull;
    final effectiveHeight = heightCm ?? profile?.heightCm;
    if (effectiveHeight == null || effectiveHeight <= 0) return;

    final bmiVal = BmiCalculator.calculate(
      weightKg: weightKg,
      heightCm: effectiveHeight,
      age: profile?.age,
    )?.bmi;
    if (bmiVal == null) return;

    final record = BmiRecord(
      id: 'bmi_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      weightKg: weightKg,
      heightCm: effectiveHeight,
      bmi: double.parse(bmiVal.toStringAsFixed(1)),
      recordedAt: DateTime.now(),
      notes: notes,
    );

    final repo = ref.read(bmiHistoryRepositoryProvider);
    await repo.addRecord(record);

    // Update state
    final currentList = state.valueOrNull ?? [];
    state = AsyncData([record, ...currentList]);

    // Update active profile weight/height
    if (profile != null) {
      final updatedProfile = profile.copyWith(
        weightKg: weightKg,
        heightCm: effectiveHeight,
      );
      await ref.read(currentProfileProvider.notifier).save(updatedProfile);
    }
  }

  /// Removes a historical record.
  Future<void> deleteMeasurement(String recordId) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    final repo = ref.read(bmiHistoryRepositoryProvider);
    await repo.deleteRecord(userId, recordId);
    final currentList = state.valueOrNull ?? [];
    state = AsyncData(currentList.where((r) => r.id != recordId).toList());
  }
}

final bmiHistoryProvider =
    AsyncNotifierProvider<BmiHistoryNotifier, List<BmiRecord>>(
  BmiHistoryNotifier.new,
);
