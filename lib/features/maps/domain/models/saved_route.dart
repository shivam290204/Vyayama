import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:latlong2/latlong.dart';

enum RouteDifficulty { easy, moderate, hard }

enum RouteElevation { flat, moderate, hilly, unknown }

enum RouteSurface { paved, trail, mixed, unknown }

/// A saved or discoverable outdoor route.
class SavedRoute {
  const SavedRoute({
    required this.id,
    required this.name,
    required this.activityType,
    required this.distanceMeters,
    required this.estimatedDurationSeconds,
    required this.difficulty,
    required this.points,
    this.elevationGainMeters,
    this.surfaceType = RouteSurface.paved,
    this.elevationProfile = RouteElevation.unknown,
    this.description = '',
    this.isSavedByUser = false,
    this.userId = 'local_user',
    this.createdAt,
    this.isLoop = true,
  });

  final String id;
  final String name;
  final OutdoorActivityType activityType;
  final double distanceMeters;
  final int estimatedDurationSeconds;
  final RouteDifficulty difficulty;
  final List<GpsPoint> points;
  final double? elevationGainMeters;
  final RouteSurface surfaceType;
  final RouteElevation elevationProfile;
  final String description;
  final bool isSavedByUser;
  final String userId;
  final DateTime? createdAt;
  final bool isLoop;

  double get distanceKm => distanceMeters / 1000.0;

  LatLng get startPoint => points.isNotEmpty
      ? points.first.toLatLng()
      : const LatLng(0, 0);

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  bool get hasElevationData => elevationGainMeters != null;

  String get formattedElevation =>
      hasElevationData ? '+${elevationGainMeters!.round()}m' : '--';

  String get formattedDuration {
    final mins = estimatedDurationSeconds ~/ 60;
    if (mins >= 60) {
      final hours = mins ~/ 60;
      final remainingMins = mins % 60;
      return '${hours}h ${remainingMins}m';
    }
    return '$mins min';
  }

  /// Evaluates whether this route is suitable for the requested [activity].
  ///
  /// Pedestrian routes (walking) on paved or mixed surfaces are also suitable
  /// for running. Dedicated hiking routes require appropriate unpaved/trail paths.
  bool isSuitableFor(OutdoorActivityType activity) {
    if (activityType == activity) return true;
    if (activity == OutdoorActivityType.running) {
      return (activityType == OutdoorActivityType.walking ||
              activityType == OutdoorActivityType.running) &&
          surfaceType != RouteSurface.trail;
    }
    if (activity == OutdoorActivityType.walking) {
      return activityType == OutdoorActivityType.running ||
          (activityType == OutdoorActivityType.hiking &&
              difficulty == RouteDifficulty.easy);
    }
    return false;
  }

  SavedRoute copyWith({
    String? id,
    String? name,
    OutdoorActivityType? activityType,
    double? distanceMeters,
    int? estimatedDurationSeconds,
    RouteDifficulty? difficulty,
    List<GpsPoint>? points,
    double? elevationGainMeters,
    bool clearElevation = false,
    RouteSurface? surfaceType,
    RouteElevation? elevationProfile,
    String? description,
    bool? isSavedByUser,
    String? userId,
    DateTime? createdAt,
    bool? isLoop,
  }) =>
      SavedRoute(
        id: id ?? this.id,
        name: name ?? this.name,
        activityType: activityType ?? this.activityType,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        estimatedDurationSeconds:
            estimatedDurationSeconds ?? this.estimatedDurationSeconds,
        difficulty: difficulty ?? this.difficulty,
        points: points ?? this.points,
        elevationGainMeters: clearElevation
            ? null
            : (elevationGainMeters ?? this.elevationGainMeters),
        surfaceType: surfaceType ?? this.surfaceType,
        elevationProfile: elevationProfile ?? this.elevationProfile,
        description: description ?? this.description,
        isSavedByUser: isSavedByUser ?? this.isSavedByUser,
        userId: userId ?? this.userId,
        createdAt: createdAt ?? this.createdAt,
        isLoop: isLoop ?? this.isLoop,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'activity_type': activityType.name,
        'distance_meters': distanceMeters,
        'estimated_duration_sec': estimatedDurationSeconds,
        'difficulty': difficulty.name,
        'points': points.map((p) => p.toJson()).toList(),
        'elevation_gain_meters': elevationGainMeters,
        'surface_type': surfaceType.name,
        'elevation_profile': elevationProfile.name,
        'description': description,
        'is_saved_by_user': isSavedByUser,
        'user_id': userId,
        'created_at': createdAt?.toIso8601String(),
        'is_loop': isLoop,
      };

  factory SavedRoute.fromJson(Map<String, dynamic> json) => SavedRoute(
        id: json['id'] as String,
        name: json['name'] as String,
        activityType: OutdoorActivityType.fromString(
            json['activity_type'] as String? ?? 'walk'),
        distanceMeters: (json['distance_meters'] as num).toDouble(),
        estimatedDurationSeconds:
            (json['estimated_duration_sec'] as num).toInt(),
        difficulty: RouteDifficulty.values.firstWhere(
          (d) => d.name == (json['difficulty'] as String? ?? 'easy'),
          orElse: () => RouteDifficulty.easy,
        ),
        points: (json['points'] as List<dynamic>?)
                ?.map((e) => GpsPoint.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        elevationGainMeters:
            (json['elevation_gain_meters'] as num?)?.toDouble(),
        surfaceType: RouteSurface.values.firstWhere(
          (s) => s.name == (json['surface_type'] as String? ?? 'paved'),
          orElse: () => RouteSurface.paved,
        ),
        elevationProfile: RouteElevation.values.firstWhere(
          (e) => e.name == (json['elevation_profile'] as String? ?? 'unknown'),
          orElse: () => RouteElevation.unknown,
        ),
        description: json['description'] as String? ?? '',
        isSavedByUser: json['is_saved_by_user'] as bool? ?? false,
        userId: json['user_id'] as String? ?? 'local_user',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        isLoop: json['is_loop'] as bool? ?? true,
      );
}
