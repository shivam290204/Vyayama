import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats_repository.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [DailyStatsRepository] backed by `daily_stats`.
class SupabaseDailyStatsRepository implements DailyStatsRepository {
  SupabaseDailyStatsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User not signed in');
    return user.id;
  }

  @override
  Future<List<DailyStats>> fetchRange(DateTime from, DateTime to) async {
    try {
      final fromStr = dayKey(from);
      final toStr = dayKey(to);

      final res = await _client
          .from('daily_stats')
          .select()
          .eq('user_id', _userId)
          .gte('date', fromStr)
          .lte('date', toStr)
          .order('date', ascending: true);

      return (res as List)
          .map((row) => DailyStats.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> upsert(DailyStats stats) async {
    try {
      final data = stats.toJson();
      data['user_id'] = _userId;

      await _client
          .from('daily_stats')
          .upsert(data, onConflict: 'user_id, date');
    } catch (_) {
      // Ignored if network or offline error occurs
    }
  }
}
