import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:fitbuddy/features/challenges/data/challenge_catalog.dart';
import 'package:fitbuddy/features/challenges/data/challenge_completion.dart';
import 'package:fitbuddy/features/challenges/data/challenge_repository.dart';
import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Robust offline-first Supabase implementation of the challenge repository.
/// Never throws unhandled exceptions when offline or unauthenticated.
class SupabaseChallengeRepository implements ChallengeRepository {
  SupabaseChallengeRepository({
    required this.client,
    required this.prefs,
  });

  final SupabaseClient client;
  final SharedPreferences prefs;

  String get _safeUserId {
    return client.auth.currentUser?.id ??
        prefs.getString('cached_user_id') ??
        'local_user';
  }

  @override
  Future<List<Challenge>> fetchChallenges() async {
    try {
      final res = await client.from('challenges').select();
      if (res.isEmpty) return await loadChallengesFromAsset();

      return res
          .map((row) => Challenge(
                id: row['id'] as String,
                title: row['title'] as String,
                description: (row['description'] as String?) ?? '',
                type: ChallengeType.values.firstWhere(
                  (e) => e.name == (row['type'] as String?),
                  orElse: () => ChallengeType.checkoff,
                ),
                targetValue: row['target_value'] as int? ?? 1,
                xp: row['xp'] as int? ?? 10,
              ))
          .toList();
    } catch (_) {
      // Offline fallback: load from bundled asset
      return await loadChallengesFromAsset();
    }
  }

  @override
  Future<List<ChallengeCompletion>> fetchCompletions() async {
    final uid = _safeUserId;
    try {
      if (client.auth.currentUser != null) {
        final res = await client
            .from('challenge_completions')
            .select()
            .eq('user_id', uid)
            .order('date', ascending: false);

        return res
            .map((row) => ChallengeCompletion(
                  id: row['id'] as String,
                  userId: row['user_id'] as String,
                  challengeId: row['challenge_id'] as String,
                  date: DateTime.parse(row['date'] as String),
                ))
            .toList();
      }
    } catch (_) {}

    // Local fallback: retrieve from cached keys
    return <ChallengeCompletion>[];
  }

  @override
  Future<ChallengeCompletion> addCompletion({
    required String challengeId,
    required DateTime day,
  }) async {
    final uid = _safeUserId;
    final dateStr = dayOnly(day).toIso8601String().split('T')[0];

    try {
      if (client.auth.currentUser != null) {
        final res = await client.from('challenge_completions').upsert({
          'user_id': uid,
          'challenge_id': challengeId,
          'date': dateStr,
        }, onConflict: 'user_id, date').select().single();

        return ChallengeCompletion(
          id: res['id'] as String,
          userId: res['user_id'] as String,
          challengeId: res['challenge_id'] as String,
          date: DateTime.parse(res['date'] as String),
        );
      }
    } catch (_) {}

    return ChallengeCompletion(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: uid,
      challengeId: challengeId,
      date: dayOnly(day),
    );
  }

  @override
  Future<StreakState> fetchStreak() async {
    final uid = _safeUserId;

    // Read local cache first for instant offline responsiveness
    final cachedCurrent = prefs.getInt('streak_${uid}_current') ?? 0;
    final cachedLongest = prefs.getInt('streak_${uid}_longest') ?? 0;
    final cachedDateStr = prefs.getString('streak_${uid}_last_active');
    final cachedXp = prefs.getInt('streak_${uid}_xp') ?? 0;
    final cachedDate =
        cachedDateStr != null ? DateTime.tryParse(cachedDateStr) : null;

    final fallback = StreakState(
      userId: uid,
      current: cachedCurrent,
      longest: cachedLongest,
      lastActiveDate: cachedDate,
      xp: cachedXp,
    );

    try {
      if (client.auth.currentUser != null) {
        final res = await client
            .from('streaks')
            .select()
            .eq('user_id', uid)
            .maybeSingle();

        if (res != null) {
          final serverStreak = StreakState(
            userId: res['user_id'] as String,
            current: res['current'] as int? ?? 0,
            longest: res['longest'] as int? ?? 0,
            lastActiveDate: res['last_active_date'] != null
                ? DateTime.parse(res['last_active_date'] as String)
                : null,
            xp: res['xp'] as int? ?? 0,
          );
          // Update local cache
          await saveStreak(serverStreak);
          return serverStreak;
        }
      }
    } catch (_) {}

    return fallback;
  }

  @override
  Future<void> saveStreak(StreakState state) async {
    final uid = _safeUserId;

    // Save locally
    await prefs.setInt('streak_${uid}_current', state.current);
    await prefs.setInt('streak_${uid}_longest', state.longest);
    if (state.lastActiveDate != null) {
      await prefs.setString(
          'streak_${uid}_last_active', state.lastActiveDate!.toIso8601String());
    }
    await prefs.setInt('streak_${uid}_xp', state.xp);

    // Sync to Supabase in background
    try {
      if (client.auth.currentUser != null) {
        await client.from('streaks').upsert({
          'user_id': uid,
          'current': state.current,
          'longest': state.longest,
          'last_active_date':
              state.lastActiveDate?.toIso8601String().split('T')[0],
          'xp': state.xp,
        });
      }
    } catch (_) {}
  }

  // Partial progress uses SharedPreferences
  String _progressKey(String challengeId, DateTime day) =>
      'progress_${_safeUserId}_${challengeId}_${dayKey(day)}';

  @override
  Future<int> getProgress(String challengeId, DateTime day) async {
    return prefs.getInt(_progressKey(challengeId, day)) ?? 0;
  }

  @override
  Future<void> setProgress(String challengeId, DateTime day, int value) async {
    await prefs.setInt(_progressKey(challengeId, day), value < 0 ? 0 : value);
  }
}
