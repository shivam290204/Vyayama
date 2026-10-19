import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats_repository.dart';
import 'package:fitbuddy/features/dashboard/data/local_daily_stats_storage.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Offline-first Supabase implementation of [DailyStatsRepository].
///
/// Steps, calories, and active time are immediately saved and loaded locally,
/// allowing 100% offline functionality. When online, changes are synced
/// bi-directionally with Supabase `daily_stats`.
class SupabaseDailyStatsRepository implements DailyStatsRepository {
  SupabaseDailyStatsRepository({
    SupabaseClient? client,
    LocalDailyStatsStorage? localStorage,
  })  : _client = client ?? Supabase.instance.client,
        _localStorage = localStorage ?? LocalDailyStatsStorage.instance;

  final SupabaseClient _client;
  final LocalDailyStatsStorage _localStorage;

  String? get _userId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DailyStats>> fetchRange(DateTime from, DateTime to) async {
    // 1. Immediately read local offline cached rows
    final localRows = await _localStorage.getRange(from, to);
    final localMap = <String, DailyStats>{
      for (final r in localRows) dayKey(r.date): r,
    };

    // 2. If online and authenticated, pull remote rows and merge
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      try {
        final fromStr = dayKey(from);
        final toStr = dayKey(to);

        final res = await _client
            .from('daily_stats')
            .select()
            .eq('user_id', uid)
            .gte('date', fromStr)
            .lte('date', toStr)
            .order('date', ascending: true);

        for (final row in res) {
          final remote = DailyStats.fromJson(Map<String, dynamic>.from(row));
          final k = dayKey(remote.date);
          final local = localMap[k];

          // If local offline steps are higher than remote, keep local and sync to cloud
          if (local != null && local.steps > remote.steps) {
            unawaited(upsert(local));
          } else {
            localMap[k] = remote;
            await _localStorage.save(remote, markPendingSync: false);
          }
        }

        // Upload any pending offline changes
        unawaited(_syncPending());
      } catch (e) {
        debugPrint('[DailyStatsRepository] Offline or sync error, using local cache: $e');
      }
    }

    final sorted = localMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  @override
  Future<void> upsert(DailyStats stats) async {
    // 1. Save to device local storage immediately (100% offline first)
    await _localStorage.save(stats, markPendingSync: true);

    // 2. Attempt cloud upload if online and authenticated
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      try {
        final data = stats.toJson();
        data['user_id'] = uid;

        await _client
            .from('daily_stats')
            .upsert(data, onConflict: 'user_id, date');

        // Cloud sync succeeded: remove from pending queue
        await _localStorage.clearPendingSyncDate(dayKey(stats.date));
      } catch (e) {
        debugPrint('[DailyStatsRepository] Remote upsert failed (offline), queued: $e');
      }
    }
  }

  /// Synchronizes any daily stats that were saved while offline.
  Future<void> _syncPending() async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;

    try {
      final pending = await _localStorage.getPendingSyncDates();
      for (final dateStr in pending) {
        try {
          final date = parseDayKey(dateStr);
          final stats = await _localStorage.get(date);
          if (stats != null) {
            final data = stats.toJson();
            data['user_id'] = uid;

            await _client
                .from('daily_stats')
                .upsert(data, onConflict: 'user_id, date');

            await _localStorage.clearPendingSyncDate(dateStr);
          }
        } catch (_) {
          // If network is still intermittent, stop and retry on next refresh
          break;
        }
      }
    } catch (_) {}
  }
}
