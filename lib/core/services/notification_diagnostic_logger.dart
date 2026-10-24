import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single notification diagnostic entry with target vs actual firing times.
class NotificationDiagnosticRecord {
  final int id;
  final String title;
  final DateTime scheduledTime;
  final DateTime scheduledAt;
  final DateTime? firedTime;
  final int? delaySeconds;
  final bool isExact;
  final String channelId;

  const NotificationDiagnosticRecord({
    required this.id,
    required this.title,
    required this.scheduledTime,
    required this.scheduledAt,
    this.firedTime,
    this.delaySeconds,
    required this.isExact,
    required this.channelId,
  });

  NotificationDiagnosticRecord copyWith({
    DateTime? firedTime,
    int? delaySeconds,
  }) {
    return NotificationDiagnosticRecord(
      id: id,
      title: title,
      scheduledTime: scheduledTime,
      scheduledAt: scheduledAt,
      firedTime: firedTime ?? this.firedTime,
      delaySeconds: delaySeconds ?? this.delaySeconds,
      isExact: isExact,
      channelId: channelId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'scheduledEpochMs': scheduledTime.millisecondsSinceEpoch,
        'scheduledAtEpochMs': scheduledAt.millisecondsSinceEpoch,
        'firedEpochMs': firedTime?.millisecondsSinceEpoch,
        'delaySeconds': delaySeconds,
        'isExact': isExact,
        'channelId': channelId,
      };

  factory NotificationDiagnosticRecord.fromJson(Map<String, dynamic> json) {
    final schedMs = json['scheduledEpochMs'] as int? ?? 0;
    final schedAtMs = json['scheduledAtEpochMs'] as int? ?? schedMs;
    final firedMs = json['firedEpochMs'] as int?;
    return NotificationDiagnosticRecord(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Reminder',
      scheduledTime: DateTime.fromMillisecondsSinceEpoch(schedMs),
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(schedAtMs),
      firedTime:
          firedMs != null ? DateTime.fromMillisecondsSinceEpoch(firedMs) : null,
      delaySeconds: json['delaySeconds'] as int?,
      isExact: json['isExact'] as bool? ?? false,
      channelId: json['channelId'] as String? ?? '',
    );
  }
}

/// Service that logs scheduled alarm timestamps and actual delivery/fire timestamps
/// so users and developers can diagnose late reminders directly on the diagnostics screen.
class NotificationDiagnosticLogger {
  NotificationDiagnosticLogger._();
  static final NotificationDiagnosticLogger instance =
      NotificationDiagnosticLogger._();

  static const String _storageKey = 'vyayama_notification_diagnostic_logs_v1';
  static const int _maxRecords = 50;

  @visibleForTesting
  SharedPreferences? overridePrefs;

  Future<SharedPreferences> _getPrefs() async {
    return overridePrefs ?? await SharedPreferences.getInstance();
  }

  /// Logs that a notification has been scheduled.
  Future<void> logScheduled({
    required int id,
    required String title,
    required DateTime scheduledTime,
    required bool isExact,
    required String channelId,
  }) async {
    try {
      final prefs = await _getPrefs();
      final records = await getRecentRecords();

      final newRecord = NotificationDiagnosticRecord(
        id: id,
        title: title,
        scheduledTime: scheduledTime,
        scheduledAt: DateTime.now(),
        isExact: isExact,
        channelId: channelId,
      );

      // Keep recent entries, removing any stale pending entry with same id
      final filtered = records.where((r) => r.id != id).toList();
      filtered.insert(0, newRecord);

      if (filtered.length > _maxRecords) {
        filtered.removeRange(_maxRecords, filtered.length);
      }

      final jsonList = filtered.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('NotificationDiagnosticLogger.logScheduled error: $e');
    }
  }

  /// Logs that a notification fired / was received.
  Future<void> logFired(int id, {DateTime? fireTime}) async {
    try {
      final prefs = await _getPrefs();
      final now = fireTime ?? DateTime.now();
      final records = await getRecentRecords();

      final index = records.indexWhere((r) => r.id == id);
      if (index != -1) {
        final existing = records[index];
        final diffSec =
            ((now.millisecondsSinceEpoch - existing.scheduledTime.millisecondsSinceEpoch) / 1000)
                .round();
        records[index] = existing.copyWith(
          firedTime: now,
          delaySeconds: diffSec,
        );
      } else {
        // Untracked/immediate notification fired
        records.insert(
          0,
          NotificationDiagnosticRecord(
            id: id,
            title: 'Delivered Notification #$id',
            scheduledTime: now,
            scheduledAt: now,
            firedTime: now,
            delaySeconds: 0,
            isExact: false,
            channelId: 'unknown',
          ),
        );
      }

      if (records.length > _maxRecords) {
        records.removeRange(_maxRecords, records.length);
      }

      final jsonList = records.map((r) => r.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('NotificationDiagnosticLogger.logFired error: $e');
    }
  }

  /// Returns recent diagnostic log records.
  Future<List<NotificationDiagnosticRecord>> getRecentRecords() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) =>
              NotificationDiagnosticRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('NotificationDiagnosticLogger.getRecentRecords error: $e');
      return [];
    }
  }

  /// Clears all stored diagnostic records.
  Future<void> clear() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('NotificationDiagnosticLogger.clear error: $e');
    }
  }
}
