import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory and persistent representation of an interrupted outdoor recording session.
class OutdoorSessionCheckpoint {
  const OutdoorSessionCheckpoint({
    required this.activityId,
    required this.activityType,
    required this.status,
    required this.startTime,
    required this.durationSeconds,
    required this.distanceMeters,
    this.points = const [],
    this.elevationGainMeters = 0.0,
    required this.lastCheckpointTime,
  });

  final String activityId;
  final OutdoorActivityType activityType;
  final OutdoorActivityStatus status;
  final DateTime startTime;
  final int durationSeconds;
  final double distanceMeters;
  final List<GpsPoint> points;
  final double elevationGainMeters;
  final DateTime lastCheckpointTime;

  Map<String, dynamic> toJson() => {
        'activity_id': activityId,
        'activity_type': activityType.name,
        'status': status.name,
        'start_time': startTime.toIso8601String(),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'points': points.map((p) => p.toJson()).toList(),
        'elevation_gain_meters': elevationGainMeters,
        'last_checkpoint_time': lastCheckpointTime.toIso8601String(),
      };

  factory OutdoorSessionCheckpoint.fromJson(Map<String, dynamic> json) {
    final pointsRaw = json['points'] as List<dynamic>? ?? [];
    return OutdoorSessionCheckpoint(
      activityId: json['activity_id'] as String,
      activityType: OutdoorActivityType.fromString(
          json['activity_type'] as String? ?? 'walk'),
      status: OutdoorActivityStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'paused'),
        orElse: () => OutdoorActivityStatus.paused,
      ),
      startTime: DateTime.parse(json['start_time'] as String),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      points: pointsRaw
          .map((p) => GpsPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      elevationGainMeters:
          (json['elevation_gain_meters'] as num?)?.toDouble() ?? 0.0,
      lastCheckpointTime:
          DateTime.parse(json['last_checkpoint_time'] as String),
    );
  }
}

/// Service managing durable session checkpointing and crash recovery.
///
/// Implements atomic file-based persistence via temporary-file writing, fsync flushing,
/// and safe atomic replacement. Guarantees ordering with monotonic sequence numbers,
/// serialized write queuing, and CRC-32 integrity validation.
class OutdoorSessionRecoveryService {
  OutdoorSessionRecoveryService({
    File? storageFile,
    Future<Directory> Function()? directoryProvider,
    SharedPreferences? legacyPrefs,
  })  : _storageFile = storageFile,
        _directoryProvider = directoryProvider,
        _legacyPrefs = legacyPrefs;

  final File? _storageFile;
  final Future<Directory> Function()? _directoryProvider;
  final SharedPreferences? _legacyPrefs;

  static const String checkpointFileName = 'vyayama_outdoor_checkpoint_v1.json';
  static const String legacyCheckpointKey = 'vyayama_active_outdoor_session_v1';

  int _sequenceCounter = 0;
  int _latestWrittenSequence = 0;
  Future<void>? _writeQueue;

  bool _hasPromptedThisLaunch = false;

  /// Whether the user has already been prompted for recovery during this app launch.
  bool get hasPromptedThisLaunch => _hasPromptedThisLaunch;

  /// Marks that the recovery prompt has been displayed to avoid showing it multiple times.
  void markPromptedThisLaunch() {
    _hasPromptedThisLaunch = true;
  }

  /// Resets the prompt state (useful for tests or explicit re-checks).
  void resetPromptedThisLaunch() {
    _hasPromptedThisLaunch = false;
  }

  /// Calculates IEEE 802.3 CRC-32 checksum to verify payload integrity against interrupted writes.
  static int computeCrc32(String input) {
    final bytes = utf8.encode(input);
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }

  Future<File> _resolveTargetFile() async {
    final file = _storageFile;
    if (file != null) return file;
    final dirProvider = _directoryProvider;
    final dir = dirProvider != null
        ? await dirProvider()
        : await getApplicationDocumentsDirectory();
    return File('${dir.path}/$checkpointFileName');
  }

  /// Atomically writes session checkpoint to local persistent storage.
  ///
  /// Uses a monotonic sequence counter to discard stale asynchronous writes and
  /// queues concurrent operations to prevent interleaved file writes.
  Future<void> saveCheckpoint(OutdoorSessionCheckpoint checkpoint) async {
    if (!isValidCheckpoint(checkpoint)) return;

    final seq = ++_sequenceCounter;
    final completer = Completer<void>();
    final previousTask = _writeQueue;
    _writeQueue = completer.future;

    try {
      if (previousTask != null) {
        try {
          await previousTask;
        } catch (_) {}
      }

      // Check if a newer checkpoint was completed while we were queued
      if (seq < _latestWrittenSequence) {
        return;
      }

      final targetFile = await _resolveTargetFile();
      final parentDir = targetFile.parent;
      if (!parentDir.existsSync()) {
        parentDir.createSync(recursive: true);
      }

      final tempFile = File('${targetFile.path}.tmp.$seq');
      final payloadJson = jsonEncode(checkpoint.toJson());
      final checksum = computeCrc32(payloadJson);

      final envelope = {
        'version': 1,
        'sequence': seq,
        'activity_id': checkpoint.activityId,
        'checksum': checksum,
        'payload': checkpoint.toJson(),
        'written_at': DateTime.now().toIso8601String(),
      };

      final serialized = jsonEncode(envelope);
      tempFile.writeAsStringSync(serialized, flush: true);

      // Windows File.rename throws if destination exists; remove destination first.
      if (Platform.isWindows && targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      tempFile.renameSync(targetFile.path);

      _latestWrittenSequence = seq;
    } catch (e) {
      debugPrint('[OutdoorSessionRecoveryService] Failed to save checkpoint: $e');
    } finally {
      completer.complete();
    }
  }

  /// Reads and parses the active session checkpoint, validating CRC-32 integrity.
  ///
  /// Returns null if missing, truncated, or corrupted.
  Future<OutdoorSessionCheckpoint?> getActiveCheckpoint() async {
    try {
      final targetFile = await _resolveTargetFile();
      if (!targetFile.existsSync()) {
        return await _checkLegacyPrefsCheckpoint();
      }

      final raw = targetFile.readAsStringSync();
      if (raw.trim().isEmpty) {
        await clearCheckpoint();
        return null;
      }

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final checksum = decoded['checksum'] as int?;
      final payload = decoded['payload'] as Map<String, dynamic>?;

      if (payload == null || checksum == null) {
        await clearCheckpoint();
        return null;
      }

      // Verify CRC-32 checksum against payload
      final payloadJson = jsonEncode(payload);
      final actualChecksum = computeCrc32(payloadJson);
      if (actualChecksum != checksum) {
        debugPrint(
            '[OutdoorSessionRecoveryService] Checkpoint CRC mismatch: expected $checksum, computed $actualChecksum');
        await clearCheckpoint();
        return null;
      }

      final checkpoint = OutdoorSessionCheckpoint.fromJson(payload);
      if (!isValidCheckpoint(checkpoint)) {
        await clearCheckpoint();
        return null;
      }

      return checkpoint;
    } catch (e) {
      debugPrint('[OutdoorSessionRecoveryService] Corrupted checkpoint detected: $e');
      await clearCheckpoint();
      return null;
    }
  }

  /// Migrates and reads legacy SharedPreferences checkpoint if present.
  Future<OutdoorSessionCheckpoint?> _checkLegacyPrefsCheckpoint() async {
    try {
      final prefs = _legacyPrefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString(legacyCheckpointKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final checkpoint = OutdoorSessionCheckpoint.fromJson(decoded);
      if (isValidCheckpoint(checkpoint)) {
        // Migrate to durable file and clean up legacy pref key
        await saveCheckpoint(checkpoint);
        await prefs.remove(legacyCheckpointKey);
        return checkpoint;
      } else {
        await prefs.remove(legacyCheckpointKey);
      }
    } catch (_) {}
    return null;
  }

  /// Removes the active session checkpoint upon clean finish or user discard.
  Future<void> clearCheckpoint() async {
    try {
      final targetFile = await _resolveTargetFile();
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }

      // Clean up any remaining temporary files
      final parentDir = targetFile.parent;
      if (parentDir.existsSync()) {
        final baseName = targetFile.uri.pathSegments.last;
        try {
          for (final entity in parentDir.listSync()) {
            if (entity is File &&
                entity.uri.pathSegments.last.startsWith('$baseName.tmp')) {
              entity.deleteSync();
            }
          }
        } catch (_) {}
      }

      // Also clean up legacy SharedPreferences key if present
      final prefs = _legacyPrefs ?? await SharedPreferences.getInstance();
      await prefs.remove(legacyCheckpointKey);
    } catch (e) {
      debugPrint('[OutdoorSessionRecoveryService] Failed to clear checkpoint: $e');
    }
  }

  /// Validates checkpoint data integrity.
  bool isValidCheckpoint(OutdoorSessionCheckpoint? checkpoint) {
    if (checkpoint == null) return false;
    if (checkpoint.activityId.trim().isEmpty) return false;
    if (checkpoint.durationSeconds < 0) return false;
    if (checkpoint.distanceMeters < 0) return false;

    // Checkpoints cannot be in distant future (> 5 mins)
    final now = DateTime.now();
    if (checkpoint.startTime.isAfter(now.add(const Duration(minutes: 5)))) {
      return false;
    }

    // Coordinates must be finite and within valid geographic boundaries
    for (final pt in checkpoint.points) {
      if (!pt.latitude.isFinite || !pt.longitude.isFinite) return false;
      if (pt.latitude < -90.0 || pt.latitude > 90.0) return false;
      if (pt.longitude < -180.0 || pt.longitude > 180.0) return false;
    }

    return true;
  }
}
