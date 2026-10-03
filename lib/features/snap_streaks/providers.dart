import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/snap_streaks/data/mock_ids.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The signed-in user's id. Falls back to a mock id until a profile loads.
final currentUserIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).valueOrNull?.id ?? kMockUserId;
});

/// Injectable clock so tests and previews can control "now".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Swap this for a Supabase-backed repository later.
final snapStreakRepositoryProvider = Provider<SnapStreakRepository>((ref) {
  return MockSnapStreakRepository(
    currentUserId: ref.watch(currentUserIdProvider),
    clock: ref.watch(clockProvider),
  );
});

/// All pair streaks of the signed-in user.
final snapStreaksProvider = FutureProvider<List<SnapStreak>>((ref) {
  return ref.watch(snapStreakRepositoryProvider).streaks();
});

/// True when a friend already sent today and the user has not (mascot: worried).
final snapStreakAtRiskProvider = Provider<bool>((ref) {
  final streaks = ref.watch(snapStreaksProvider).valueOrNull;
  if (streaks == null) return false;
  final me = ref.watch(currentUserIdProvider);
  final now = ref.watch(clockProvider)().toUtc();
  return streaks.any((s) => SnapStreakCalculator.friendSentIAmNot(s, me, now));
});
