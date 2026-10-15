import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [SnapStreakRepository] backed by table `snap_streaks`.
class SupabaseSnapStreakRepository implements SnapStreakRepository {
  SupabaseSnapStreakRepository({
    SupabaseClient? client,
    required this.clock,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final DateTime Function() clock;

  @override
  Future<List<SnapStreak>> streaks() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    try {
      final res = await _client
          .from('snap_streaks')
          .select()
          .or('user_a.eq.$uid,user_b.eq.$uid');

      final now = clock().toUtc();
      return (res as List)
          .map((row) => SnapStreak.fromJson(Map<String, dynamic>.from(row as Map)))
          .map((s) => SnapStreakCalculator.expireIfMissed(s, now))
          .toList();
    } catch (e) {
      debugPrint('Warning: Failed to fetch snap streaks from Supabase: $e');
      return const [];
    }
  }
}
