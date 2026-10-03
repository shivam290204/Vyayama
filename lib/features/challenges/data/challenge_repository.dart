import 'package:fitbuddy/features/challenges/daily_challenge_picker.dart';
import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:fitbuddy/features/challenges/data/challenge_catalog.dart';
import 'package:fitbuddy/features/challenges/data/challenge_completion.dart';
import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';

/// Storage for challenges, completions, the streak and partial progress.
///
/// Antigravity will add a Supabase implementation later. The streak row must
/// only be written by the signed-in user's own account (RLS `user_id`).
abstract class ChallengeRepository {
  /// All challenges available for the daily rotation.
  Future<List<Challenge>> fetchChallenges();

  /// All of the user's completions, newest first.
  Future<List<ChallengeCompletion>> fetchCompletions();

  /// Records that [challengeId] was completed on [day].
  ///
  /// There is one completion per user and day (`unique (user_id, date)`),
  /// so a second call for the same day returns the existing row.
  Future<ChallengeCompletion> addCompletion({
    required String challengeId,
    required DateTime day,
  });

  /// The user's streak and XP row (an empty state if none exists yet).
  Future<StreakState> fetchStreak();

  /// Saves the streak and XP row.
  Future<void> saveStreak(StreakState state);

  /// Partial progress for [challengeId] on [day] (for example 12 squats).
  ///
  /// There is no table for this in the schema: back it with
  /// `shared_preferences` or a new column.
  Future<int> getProgress(String challengeId, DateTime day);

  /// Stores partial progress.
  Future<void> setProgress(String challengeId, DateTime day, int value);
}

/// In-memory repository with a short demo history.
///
/// By default it seeds the three days before today as completed with a
/// streak of 3, so the UI has something to show.
class MockChallengeRepository implements ChallengeRepository {
  /// Creates the mock.
  ///
  /// [catalog] defaults to the bundled JSON; pass a loader in tests.
  /// [clock] defaults to `DateTime.now`.
  MockChallengeRepository({
    Future<List<Challenge>> Function()? catalog,
    DateTime Function()? clock,
    this.seedDemoHistory = true,
  })  : _catalog = catalog ?? loadChallengesFromAsset,
        _clock = clock ?? DateTime.now;

  /// User id used by the mock.
  static const String mockUserId = 'mock-user';

  /// Whether to pre-fill three days of history.
  final bool seedDemoHistory;

  final Future<List<Challenge>> Function() _catalog;
  final DateTime Function() _clock;

  List<Challenge>? _challenges;
  Future<void>? _seeding;
  final List<ChallengeCompletion> _completions = [];
  final Map<String, int> _progress = {};
  StreakState _streak = StreakState.empty(mockUserId);
  int _nextId = 1;

  Future<List<Challenge>> _load() async => _challenges ??= await _catalog();

  Future<void> _ensureSeeded() => _seeding ??= _seed();

  Future<void> _seed() async {
    if (!seedDemoHistory) return;
    final all = await _load();
    final today = dayOnly(_clock());
    const picker = DailyChallengePicker();
    var xp = 0;
    for (var i = 3; i >= 1; i--) {
      final day = DateTime(today.year, today.month, today.day - i);
      final challenge = picker.pickFor(all, day);
      if (challenge == null) continue;
      xp += challenge.xp;
      _completions.add(
        ChallengeCompletion(
          id: 'cc-${_nextId++}',
          userId: mockUserId,
          challengeId: challenge.id,
          date: day,
        ),
      );
    }
    if (_completions.isNotEmpty) {
      _streak = StreakState(
        userId: mockUserId,
        current: 3,
        longest: 5,
        lastActiveDate: DateTime(today.year, today.month, today.day - 1),
        xp: xp + 40,
      );
    }
  }

  String _key(String challengeId, DateTime day) =>
      '$challengeId|${dayKey(day)}';

  @override
  Future<List<Challenge>> fetchChallenges() => _load();

  @override
  Future<List<ChallengeCompletion>> fetchCompletions() async {
    await _ensureSeeded();
    final sorted = [..._completions]
      ..sort((a, b) => b.date.compareTo(a.date));
    return List<ChallengeCompletion>.unmodifiable(sorted);
  }

  @override
  Future<ChallengeCompletion> addCompletion({
    required String challengeId,
    required DateTime day,
  }) async {
    await _ensureSeeded();
    final existing = _completions
        .where((c) => isSameDay(c.date, day))
        .cast<ChallengeCompletion?>()
        .firstOrNull;
    if (existing != null) return existing;
    final created = ChallengeCompletion(
      id: 'cc-${_nextId++}',
      userId: mockUserId,
      challengeId: challengeId,
      date: dayOnly(day),
    );
    _completions.add(created);
    return created;
  }

  @override
  Future<StreakState> fetchStreak() async {
    await _ensureSeeded();
    return _streak;
  }

  @override
  Future<void> saveStreak(StreakState state) async {
    await _ensureSeeded();
    _streak = state;
  }

  @override
  Future<int> getProgress(String challengeId, DateTime day) async =>
      _progress[_key(challengeId, day)] ?? 0;

  @override
  Future<void> setProgress(String challengeId, DateTime day, int value) async {
    _progress[_key(challengeId, day)] = value < 0 ? 0 : value;
  }
}
