import 'package:latlong2/latlong.dart';

/// Single validated GPS coordinate point captured during outdoor recording.
class GpsPoint {
  const GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude = 0.0,
    this.accuracy = 0.0,
    this.speed = 0.0,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double altitude;
  final double accuracy;
  final double speed;

  LatLng toLatLng() => LatLng(latitude, longitude);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'altitude': altitude,
        'accuracy': accuracy,
        'speed': speed,
      };

  factory GpsPoint.fromJson(Map<String, dynamic> json) => GpsPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
        speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
      );
}

