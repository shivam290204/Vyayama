import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:fitbuddy/features/challenges/data/challenge_catalog.dart';
import 'package:fitbuddy/features/challenges/data/challenge_completion.dart';
import 'package:fitbuddy/features/challenges/data/challenge_repository.dart';
import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of the challenge repository.
class SupabaseChallengeRepository implements ChallengeRepository {
  SupabaseChallengeRepository({
    required this.client,
    required this.prefs,
  });

  final SupabaseClient client;
  final SharedPreferences prefs;

  String get _userId {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not signed in');
    return user.id;
  }

  @override
  Future<List<Challenge>> fetchChallenges() async {
    try {
      final res = await client.from('challenges').select();
      if (res.isEmpty) return await loadChallengesFromAsset();
      
      return res.map((row) => Challenge(
        id: row['id'] as String,
        title: row['title'] as String,
        description: (row['description'] as String?) ?? '',
        type: ChallengeType.values.firstWhere(
          (e) => e.name == (row['type'] as String?),
          orElse: () => ChallengeType.checkoff,
        ),
        targetValue: row['target_value'] as int? ?? 1,
        xp: row['xp'] as int? ?? 10,
      )).toList();
    } catch (_) {
      // Fallback if table doesn't exist or RLS blocks
      return await loadChallengesFromAsset();
    }
  }

  @override
  Future<List<ChallengeCompletion>> fetchCompletions() async {
    try {
      final res = await client
          .from('challenge_completions')
          .select()
          .eq('user_id', _userId)
          .order('date', ascending: false);
          
      return res.map((row) => ChallengeCompletion(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        challengeId: row['challenge_id'] as String,
        date: DateTime.parse(row['date'] as String),
      )).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ChallengeCompletion> addCompletion({
    required String challengeId,
    required DateTime day,
  }) async {
    final dateStr = dayOnly(day).toIso8601String().split('T')[0];
    
    try {
      // UPSERT basically, if exists ignore or update
      final res = await client.from('challenge_completions').upsert({
        'user_id': _userId,
        'challenge_id': challengeId,
        'date': dateStr,
      }, onConflict: 'user_id, date').select().single();
      
      return ChallengeCompletion(
        id: res['id'] as String,
        userId: res['user_id'] as String,
        challengeId: res['challenge_id'] as String,
        date: DateTime.parse(res['date'] as String),
      );
    } catch (_) {
      // Fallback
      return ChallengeCompletion(
        id: 'fallback',
        userId: _userId,
        challengeId: challengeId,
        date: dayOnly(day),
      );
    }
  }

  @override
  Future<StreakState> fetchStreak() async {
    try {
      final res = await client
          .from('streaks')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();
          
      if (res == null) {
        return StreakState.empty(_userId);
      }
      
      return StreakState(
        userId: res['user_id'] as String,
        current: res['current'] as int? ?? 0,
        longest: res['longest'] as int? ?? 0,
        lastActiveDate: res['last_active_date'] != null 
            ? DateTime.parse(res['last_active_date'] as String) 
            : null,
        xp: res['xp'] as int? ?? 0,
      );
    } catch (_) {
      return StreakState.empty(_userId);
    }
  }

  @override
  Future<void> saveStreak(StreakState state) async {
    try {
      await client.from('streaks').upsert({
        'user_id': _userId,
        'current': state.current,
        'longest': state.longest,
        'last_active_date': state.lastActiveDate?.toIso8601String().split('T')[0],
        'xp': state.xp,
      });
    } catch (_) {
      // Ignored if table doesn't exist
    }
  }

  // Partial progress uses SharedPreferences since there is no table for it
  String _progressKey(String challengeId, DateTime day) =>
      'progress_${_userId}_${challengeId}_${dayKey(day)}';

  @override
  Future<int> getProgress(String challengeId, DateTime day) async {
    return prefs.getInt(_progressKey(challengeId, day)) ?? 0;
  }

  @override
  Future<void> setProgress(String challengeId, DateTime day, int value) async {
    await prefs.setInt(_progressKey(challengeId, day), value < 0 ? 0 : value);
  }
}
