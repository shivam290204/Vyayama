import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';

/// Local offline-first persistent storage for daily activity statistics.
///
/// Ensures steps, calories, and active minutes are reliably saved on the device
/// and instantly accessible without an internet connection.
class LocalDailyStatsStorage {
  LocalDailyStatsStorage._();
  static final LocalDailyStatsStorage instance = LocalDailyStatsStorage._();

  static const String _statsKeyPrefix = 'local_daily_stats_';
  static const String _pendingSyncKey = 'pending_sync_daily_stats_dates';

  /// Saves [stats] for its date into local persistent storage.
  /// If [markPendingSync] is true, records this date in the offline sync queue.
  Future<void> save(DailyStats stats, {bool markPendingSync = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKeyStr = dayKey(stats.date);
      final key = '$_statsKeyPrefix$dateKeyStr';

      final jsonMap = stats.toJson();
      await prefs.setString(key, jsonEncode(jsonMap));

      // Also maintain legacy step key for seamless backward compatibility
      await prefs.setInt('today_steps_$dateKeyStr', stats.steps);

      if (markPendingSync) {
        final pending = prefs.getStringList(_pendingSyncKey) ?? [];
        if (!pending.contains(dateKeyStr)) {
          pending.add(dateKeyStr);
          await prefs.setStringList(_pendingSyncKey, pending);
        }
      }
    } catch (e) {
      debugPrint('[LocalDailyStatsStorage] save error: $e');
    }
  }

  /// Retrieves cached daily stats for a specific [date].
  Future<DailyStats?> get(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateKeyStr = dayKey(date);
      final key = '$_statsKeyPrefix$dateKeyStr';

      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return DailyStats.fromJson(map);
      }

      // Check legacy step key fallback
      final legacySteps = prefs.getInt('today_steps_$dateKeyStr');
      if (legacySteps != null && legacySteps > 0) {
        return DailyStats(
          date: date,
          steps: legacySteps,
          calories: (legacySteps * 0.04).round(),
          activeMinutes: (legacySteps / 100).ceil(),
        );
      }
    } catch (e) {
      debugPrint('[LocalDailyStatsStorage] get error: $e');
    }
    return null;
  }

  /// Retrieves all cached daily stats in the date range [from] to [to] inclusive.
  Future<List<DailyStats>> getRange(DateTime from, DateTime to) async {
    final results = <DailyStats>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final end = dayOnly(to);

      for (var d = dayOnly(from);
          !d.isAfter(end);
          d = DateTime(d.year, d.month, d.day + 1)) {
        final dateKeyStr = dayKey(d);
        final key = '$_statsKeyPrefix$dateKeyStr';

        final jsonStr = prefs.getString(key);
        if (jsonStr != null && jsonStr.isNotEmpty) {
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            results.add(DailyStats.fromJson(map));
            continue;
          } catch (_) {}
        }

        // Fallback to legacy step storage if available
        final legacySteps = prefs.getInt('today_steps_$dateKeyStr');
        if (legacySteps != null && legacySteps > 0) {
          results.add(DailyStats(
            date: d,
            steps: legacySteps,
            calories: (legacySteps * 0.04).round(),
            activeMinutes: (legacySteps / 100).ceil(),
          ));
        }
      }
    } catch (e) {
      debugPrint('[LocalDailyStatsStorage] getRange error: $e');
    }
    return results;
  }

  /// Returns date strings that were saved offline and need to be synced to cloud.
  Future<List<String>> getPendingSyncDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_pendingSyncKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Removes [dateStr] from the offline pending sync queue after successful cloud sync.
  Future<void> clearPendingSyncDate(String dateStr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_pendingSyncKey) ?? [];
      pending.remove(dateStr);
      await prefs.setStringList(_pendingSyncKey, pending);
    } catch (_) {}
  }
}
