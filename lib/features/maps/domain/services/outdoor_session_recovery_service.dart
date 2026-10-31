import 'dart:convert';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serializable checkpoint representing an active, in-progress outdoor session.
class OutdoorSessionCheckpoint {
  const OutdoorSessionCheckpoint({
    required this.activityId,
    required this.activityType,
    required this.status,
    required this.startTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.points,
    required this.lastCheckpointTime,
    this.elevationGainMeters = 0.0,
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

/// Service managing persistent session checkpointing and crash recovery.
class OutdoorSessionRecoveryService {
  OutdoorSessionRecoveryService({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const String checkpointKey = 'vyayama_active_outdoor_session_v1';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Atomically writes session checkpoint to local persistent storage.
  Future<void> saveCheckpoint(OutdoorSessionCheckpoint checkpoint) async {
    if (!isValidCheckpoint(checkpoint)) return;
    final prefs = await _getPrefs();
    final jsonStr = jsonEncode(checkpoint.toJson());
    await prefs.setString(checkpointKey, jsonStr);
  }

  /// Reads and parses the active session checkpoint, returning null if missing or invalid.
  Future<OutdoorSessionCheckpoint?> getActiveCheckpoint() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(checkpointKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final checkpoint = OutdoorSessionCheckpoint.fromJson(decoded);
      if (!isValidCheckpoint(checkpoint)) {
        await clearCheckpoint();
        return null;
      }
      return checkpoint;
    } catch (_) {
      // In case of corrupt JSON, clear and return null
      await clearCheckpoint();
      return null;
    }
  }

  /// Removes the active session checkpoint upon clean finish or user discard.
  Future<void> clearCheckpoint() async {
    final prefs = await _getPrefs();
    await prefs.remove(checkpointKey);
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

