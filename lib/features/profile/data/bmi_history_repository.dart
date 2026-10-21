import 'dart:convert';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/profile/data/bmi_record.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Offline-first repository for historical BMI and weight measurements.
class BmiHistoryRepository {
  BmiHistoryRepository({SupabaseClient? client})
      : _client = client ?? (Env.isSupabaseConfigured ? Supabase.instance.client : null);

  final SupabaseClient? _client;

  String _localKey(String userId) => 'local_bmi_history_$userId';

  /// Fetches all BMI records for [userId], ordered newest first.
  Future<List<BmiRecord>> getHistory(String userId) async {
    final records = <BmiRecord>[];

    // 1. Read local offline storage first
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey(userId));
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        for (final item in list) {
          records.add(BmiRecord.fromJson(Map<String, dynamic>.from(item as Map)));
        }
      }
    } catch (e) {
      debugPrint('[BmiHistoryRepository] Local fetch notice: $e');
    }

    // 2. If online and authenticated, fetch remote and merge
    final client = _client;
    if (client != null && client.auth.currentUser?.id == userId) {
      try {
        final res = await client
            .from('bmi_records')
            .select()
            .eq('user_id', userId)
            .order('recorded_at', ascending: false);

        if (res.isNotEmpty) {
          final remoteMap = <String, BmiRecord>{};
          for (final row in res) {
            final rec = BmiRecord.fromJson(Map<String, dynamic>.from(row as Map));
            remoteMap[rec.id] = rec;
          }
          for (final local in records) {
            remoteMap.putIfAbsent(local.id, () => local);
          }
          final merged = remoteMap.values.toList()
            ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

          // Cache merged list locally
          await _saveLocal(userId, merged);
          return merged;
        }
      } catch (e) {
        debugPrint('[BmiHistoryRepository] Remote fetch notice (using offline): $e');
      }
    }

    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return records;
  }

  /// Appends a new measurement record.
  Future<void> addRecord(BmiRecord record) async {
    final existing = await getHistory(record.userId);
    existing.removeWhere((r) => r.id == record.id);
    existing.insert(0, record);
    existing.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    // Save locally
    await _saveLocal(record.userId, existing);

    // Save remotely if available
    final client = _client;
    if (client != null && client.auth.currentUser?.id == record.userId) {
      try {
        await client.from('bmi_records').upsert(record.toJson());
      } catch (e) {
        debugPrint('[BmiHistoryRepository] Remote upsert queued/ignored: $e');
      }
    }
  }

  /// Deletes a measurement record.
  Future<void> deleteRecord(String userId, String recordId) async {
    final existing = await getHistory(userId);
    existing.removeWhere((r) => r.id == recordId);
    await _saveLocal(userId, existing);

    final client = _client;
    if (client != null && client.auth.currentUser?.id == userId) {
      try {
        await client.from('bmi_records').delete().eq('id', recordId);
      } catch (e) {
        debugPrint('[BmiHistoryRepository] Remote delete error: $e');
      }
    }
  }

  Future<void> _saveLocal(String userId, List<BmiRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = records.map((r) => r.toJson()).toList();
      await prefs.setString(_localKey(userId), jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[BmiHistoryRepository] Save local error: $e');
    }
  }
}
