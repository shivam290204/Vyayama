import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/data/friend_repository.dart';
import 'package:fitbuddy/features/friends/data/mock_friend_repository.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Swap this for a Supabase-backed repository later.
final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  return MockFriendRepository(currentUserId: ref.watch(currentUserIdProvider));
});

/// Accepted friends.
final friendsProvider = FutureProvider<List<FriendUser>>((ref) {
  return ref.watch(friendRepositoryProvider).friends();
});

/// Incoming and outgoing pending requests.
final friendRequestsProvider = FutureProvider<List<FriendRequest>>((ref) {
  return ref.watch(friendRepositoryProvider).requests();
});

/// Number of requests waiting for the user (for badges).
final incomingRequestCountProvider = Provider<int>((ref) {
  final list = ref.watch(friendRequestsProvider).valueOrNull ?? const [];
  return list.where((r) => r.incoming).length;
});

SnapStreak? _streakWith(List<SnapStreak> all, String me, String friendId) {
  for (final s in all) {
    if (s.partnerOf(me) == friendId && s.sideOf(me) != null) return s;
  }
  return null;
}

/// Friends joined with their pair streak.
final friendsWithStreakProvider =
    FutureProvider<List<FriendWithStreak>>((ref) async {
  final friends = await ref.watch(friendsProvider.future);
  final streaks = await ref.watch(snapStreaksProvider.future);
  final me = ref.watch(currentUserIdProvider);
  return [
    for (final f in friends)
      FriendWithStreak(user: f, streak: _streakWith(streaks, me, f.id)),
  ];
});

/// One friend with their streak, or null if they are no longer a friend.
final friendDetailProvider =
    FutureProvider.family<FriendWithStreak?, String>((ref, id) async {
  final all = await ref.watch(friendsWithStreakProvider.future);
  for (final f in all) {
    if (f.user.id == id) return f;
  }
  return null;
});

/// Refreshes everything that depends on the friend graph.
void invalidateFriendData(WidgetRef ref) {
  ref
    ..invalidate(friendsProvider)
    ..invalidate(friendRequestsProvider)
    ..invalidate(snapStreaksProvider)
    ..invalidate(friendsWithStreakProvider);
}
