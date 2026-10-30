import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';

enum OutdoorActivityStatus { active, paused, completed, discarded }

/// Completed or in-progress outdoor GPS activity.
class OutdoorActivity {
  const OutdoorActivity({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.averagePaceSecondsPerKm,
    required this.averageSpeedKmh,
    required this.points,
    this.elevationGainMeters = 0.0,
    this.caloriesBurned = 0,
    this.status = OutdoorActivityStatus.completed,
    this.isSynced = false,
    this.title = '',
  });

  final String id;
  final String userId;
  final OutdoorActivityType activityType;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final double distanceMeters;
  final int averagePaceSecondsPerKm;
  final double averageSpeedKmh;
  final List<GpsPoint> points;
  final double elevationGainMeters;
  final int caloriesBurned;
  final OutdoorActivityStatus status;
  final bool isSynced;
  final String title;

  double get distanceKm => distanceMeters / 1000.0;

  String get formattedPace {
    if (averagePaceSecondsPerKm <= 0 || averagePaceSecondsPerKm > 3600) {
      return '--:-- /km';
    }
    final mins = averagePaceSecondsPerKm ~/ 60;
    final secs = averagePaceSecondsPerKm % 60;
    return '$mins:${secs.toString().padLeft(2, '0')} /km';
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final mins = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;
    if (hours > 0) {
      return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  OutdoorActivity copyWith({
    String? id,
    String? userId,
    OutdoorActivityType? activityType,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    double? distanceMeters,
    int? averagePaceSecondsPerKm,
    double? averageSpeedKmh,
    List<GpsPoint>? points,
    double? elevationGainMeters,
    int? caloriesBurned,
    OutdoorActivityStatus? status,
    bool? isSynced,
    String? title,
  }) =>
      OutdoorActivity(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        activityType: activityType ?? this.activityType,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        averagePaceSecondsPerKm:
            averagePaceSecondsPerKm ?? this.averagePaceSecondsPerKm,
        averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
        points: points ?? this.points,
        elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
        caloriesBurned: caloriesBurned ?? this.caloriesBurned,
        status: status ?? this.status,
        isSynced: isSynced ?? this.isSynced,
        title: title ?? this.title,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'activity_type': activityType.name,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'average_pace_sec_km': averagePaceSecondsPerKm,
        'average_speed_kmh': averageSpeedKmh,
        'points': points.map((p) => p.toJson()).toList(),
        'elevation_gain_meters': elevationGainMeters,
        'calories_burned': caloriesBurned,
        'status': status.name,
        'is_synced': isSynced,
        'title': title,
      };

  factory OutdoorActivity.fromJson(Map<String, dynamic> json) => OutdoorActivity(
        id: json['id'] as String,
        userId: json['user_id'] as String? ?? 'local_user',
        activityType:
            OutdoorActivityType.fromString(json['activity_type'] as String? ?? 'walk'),
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        durationSeconds: (json['duration_seconds'] as num).toInt(),
        distanceMeters: (json['distance_meters'] as num).toDouble(),
        averagePaceSecondsPerKm: (json['average_pace_sec_km'] as num).toInt(),
        averageSpeedKmh: (json['average_speed_kmh'] as num).toDouble(),
        points: (json['points'] as List<dynamic>?)
                ?.map((e) => GpsPoint.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        elevationGainMeters:
            (json['elevation_gain_meters'] as num?)?.toDouble() ?? 0.0,
        caloriesBurned: (json['calories_burned'] as num?)?.toInt() ?? 0,
        status: OutdoorActivityStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String? ?? 'completed'),
          orElse: () => OutdoorActivityStatus.completed,
        ),
        isSynced: json['is_synced'] as bool? ?? false,
        title: json['title'] as String? ?? '',
      );
}

