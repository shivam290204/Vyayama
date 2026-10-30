import 'dart:math' as math;
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:latlong2/latlong.dart';

enum RouteDifficulty { easy, moderate, hard }

enum RouteElevation { flat, moderate, hilly, unknown }

enum RouteSurface { paved, trail, mixed, unknown }

/// Calculates great-circle distance between two coordinates in meters.
double routeHaversineDistance(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
  final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
  final lat1 = a.latitude * math.pi / 180.0;
  final lat2 = b.latitude * math.pi / 180.0;

  final sinDlat = math.sin(dLat / 2.0);
  final sinDlon = math.sin(dLon / 2.0);
  final aHarv =
      sinDlat * sinDlat + math.cos(lat1) * math.cos(lat2) * sinDlon * sinDlon;
  final cHarv = 2.0 * math.atan2(math.sqrt(aHarv), math.sqrt(1.0 - aHarv));
  return earthRadius * cHarv;
}

/// Analyzes route coordinates to determine if they form a genuine closed loop
/// circuit rather than a retraced out-and-back or an open/incomplete path.
bool isClosedLoopGeometry(List<LatLng> points, [double? totalDistanceMeters]) {
  if (points.length < 10) return false;

  double totalDist = totalDistanceMeters ?? 0.0;
  if (totalDist <= 0.0) {
    for (int i = 0; i < points.length - 1; i++) {
      totalDist += routeHaversineDistance(points[i], points[i + 1]);
    }
  }
  if (totalDist < 300.0) return false;

  // 1. Must start and finish in the same general area (< 200m apart)
  final start = points.first;
  final end = points.last;
  final closureDistance = routeHaversineDistance(start, end);
  if (closureDistance > 200.0) return false;

  // 2. Identify turnaround point (farthest point from start)
  int maxDistIdx = 0;
  double maxDist = 0.0;
  for (int i = 0; i < points.length; i++) {
    final d = routeHaversineDistance(start, points[i]);
    if (d > maxDist) {
      maxDist = d;
      maxDistIdx = i;
    }
  }

  // Must move at least 80m away from the start
  if (maxDist < 80.0) return false;

  // Turnaround point must occur between 15% and 85% of route points
  if (maxDistIdx < points.length * 0.15 || maxDistIdx > points.length * 0.85) {
    return false;
  }

  // 3. Compare outbound leg (start -> turnaround) with inbound leg (turnaround -> end)
  final outbound = points.sublist(0, maxDistIdx + 1);
  final inbound = points.sublist(maxDistIdx);

  if (outbound.length < 4 || inbound.length < 4) return false;

  // Sample outbound leg away from the endpoints (where start and turnaround meet)
  final sampleStart = (outbound.length * 0.15).round();
  final sampleEnd = (outbound.length * 0.85).round();
  if (sampleStart >= sampleEnd) return false;

  int retracedMatches = 0;
  int sampleCount = 0;
  double maxSeparation = 0.0;

  final step = math.max(1, (sampleEnd - sampleStart) ~/ 12);
  for (int i = sampleStart; i < sampleEnd; i += step) {
    sampleCount++;
    final pt = outbound[i];

    // Find minimum distance from this outbound sample to any inbound point
    double minInboundDist = double.infinity;
    for (int j = 0; j < inbound.length; j++) {
      final d = routeHaversineDistance(pt, inbound[j]);
      if (d < minInboundDist) {
        minInboundDist = d;
      }
    }

    if (minInboundDist > maxSeparation) {
      maxSeparation = minInboundDist;
    }

    // If within 30m of the return path, it's retracing
    if (minInboundDist < 30.0) {
      retracedMatches++;
    }
  }

  if (sampleCount == 0) return false;

  // In an out-and-back route, maxSeparation is small (<45m) and almost all
  // samples retrace (>60%). In a genuine loop, paths diverge with significant lateral separation.
  final retraceRatio = retracedMatches / sampleCount;
  final hasSignificantSeparation = maxSeparation >= 45.0;

  return retraceRatio < 0.60 && hasSignificantSeparation;
}

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
    this.surfaceType = RouteSurface.unknown,
    this.elevationProfile = RouteElevation.unknown,
    this.description = '',
    this.isSavedByUser = false,
    this.userId = 'local_user',
    this.createdAt,
    this.isLoop = false,
    this.isDifficultyEstimated = false,
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
  final bool isDifficultyEstimated;

  double get distanceKm => distanceMeters / 1000.0;

  LatLng get startPoint => points.isNotEmpty
      ? points.first.toLatLng()
      : const LatLng(0, 0);

  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  bool get hasElevationData => elevationGainMeters != null;

  String get formattedElevation =>
      hasElevationData ? '+${elevationGainMeters!.round()}m' : '--';

  String get formattedDifficulty {
    final base = difficulty.name[0].toUpperCase() + difficulty.name.substring(1);
    return isDifficultyEstimated ? 'Est. $base' : base;
  }

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
    bool? isDifficultyEstimated,
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
        isDifficultyEstimated:
            isDifficultyEstimated ?? this.isDifficultyEstimated,
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
        'is_difficulty_estimated': isDifficultyEstimated,
      };

  factory SavedRoute.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>?)
            ?.map((e) => GpsPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final explicitIsLoop = json['is_loop'] as bool?;
    final bool resolvedIsLoop;
    if (explicitIsLoop != null) {
      resolvedIsLoop = explicitIsLoop;
    } else if (points.length >= 10) {
      resolvedIsLoop = isClosedLoopGeometry(
        points.map((p) => p.toLatLng()).toList(),
        (json['distance_meters'] as num?)?.toDouble(),
      );
    } else {
      resolvedIsLoop = false;
    }

    return SavedRoute(
      id: json['id'] as String? ?? 'route_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Discovered Route',
      activityType: OutdoorActivityType.fromString(
          json['activity_type'] as String? ?? 'walk'),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      estimatedDurationSeconds:
          (json['estimated_duration_sec'] as num?)?.toInt() ?? 0,
      difficulty: RouteDifficulty.values.firstWhere(
        (d) => d.name == (json['difficulty'] as String? ?? 'easy'),
        orElse: () => RouteDifficulty.easy,
      ),
      points: points,
      elevationGainMeters:
          (json['elevation_gain_meters'] as num?)?.toDouble(),
      surfaceType: RouteSurface.values.firstWhere(
        (s) => s.name == (json['surface_type'] as String? ?? 'unknown'),
        orElse: () => RouteSurface.unknown,
      ),
      elevationProfile: RouteElevation.values.firstWhere(
        (e) => e.name == (json['elevation_profile'] as String? ?? 'unknown'),
        orElse: () => RouteElevation.unknown,
      ),
      description: json['description'] as String? ?? '',
      isSavedByUser: json['is_saved_by_user'] as bool? ?? false,
      userId: json['user_id'] as String? ?? 'local_user',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      isLoop: resolvedIsLoop,
      isDifficultyEstimated:
          json['is_difficulty_estimated'] as bool? ?? false,
    );
  }
}
