import 'package:fitbuddy/features/snap_streaks/data/mock_ids.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';

/// Read-only access to the pair streaks of the signed-in user.
///
/// Streaks are written only by the server (`update_snap_streaks`), so there is
/// intentionally no write method here.
abstract class SnapStreakRepository {
  Future<List<SnapStreak>> streaks();
}

/// In-memory repository that also simulates the server-side update so the UI
/// reacts when a mock snap is "verified".
class MockSnapStreakRepository implements SnapStreakRepository {
  MockSnapStreakRepository({required this.currentUserId, required this.clock}) {
    _seed();
  }

  final String currentUserId;
  final DateTime Function() clock;
  final List<SnapStreak> _streaks = [];

  SnapStreak _make(
    String other, {
    required int current,
    required int longest,
    DateTime? mine,
    DateTime? theirs,
    DateTime? completed,
  }) {
    final (a, b) = orderedPair(currentUserId, other);
    final meIsA = a == currentUserId;
    return SnapStreak(
      id: 'streak-$other',
      userA: a,
      userB: b,
      current: current,
      longest: longest,
      lastASnapDate: meIsA ? mine : theirs,
      lastBSnapDate: meIsA ? theirs : mine,
      lastCompletedDate: completed,
      timezone: kMockTimezone,
      createdAt: clock().toUtc(),
    );
  }

  void _seed() {
    final today = SnapStreakCalculator.localDate(clock().toUtc(), kMockTimezone);
    DateTime ago(int d) => today.subtract(Duration(days: d));
    _streaks
      ..add(_make(kMockSamId,
          current: 5, longest: 9, mine: ago(1), theirs: today, completed: ago(1)))
      ..add(_make(kMockPriyaId,
          current: 12, longest: 12, mine: today, theirs: today, completed: today))
      ..add(_make(kMockArjunId,
          current: 0, longest: 4, mine: ago(5), theirs: ago(5), completed: ago(5)));
  }

  @override
  Future<List<SnapStreak>> streaks() async {
    final now = clock().toUtc();
    return List.unmodifiable(
      _streaks.map((s) => SnapStreakCalculator.expireIfMissed(s, now)),
    );
  }

  /// Simulates `update_snap_streaks` for one sender/recipient pair.
  StreakUpdate simulateServerUpdate({
    required String senderId,
    required String recipientId,
    bool verified = true,
    bool isStory = false,
  }) {
    final (a, b) = orderedPair(senderId, recipientId);
    var index = _streaks.indexWhere((s) => s.userA == a && s.userB == b);
    if (index < 0) {
      _streaks.add(SnapStreak(
        id: 'streak-$recipientId',
        userA: a,
        userB: b,
        timezone: kMockTimezone,
        createdAt: clock().toUtc(),
      ));
      index = _streaks.length - 1;
    }
    final result = SnapStreakCalculator.applySnap(
      streak: SnapStreakCalculator.expireIfMissed(_streaks[index], clock().toUtc()),
      sender: senderId == a ? StreakSide.a : StreakSide.b,
      nowUtc: clock().toUtc(),
      verified: verified,
      isStory: isStory,
    );
    _streaks[index] = result.streak;
    return result;
  }
}
