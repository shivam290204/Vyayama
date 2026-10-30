import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';

/// User-selectable filter options for route discovery.
class RouteFilter {
  const RouteFilter({
    this.activityType,
    this.minDistanceKm,
    this.maxDistanceKm,
    this.difficulty,
    this.elevation,
    this.surface,
    this.searchQuery = '',
  });

  final OutdoorActivityType? activityType;
  final double? minDistanceKm;
  final double? maxDistanceKm;
  final RouteDifficulty? difficulty;
  final RouteElevation? elevation;
  final RouteSurface? surface;
  final String searchQuery;

  bool matches(SavedRoute route) {
    if (activityType != null && route.activityType != activityType) {
      return false;
    }
    if (minDistanceKm != null && route.distanceKm < minDistanceKm!) {
      return false;
    }
    if (maxDistanceKm != null && route.distanceKm > maxDistanceKm!) {
      return false;
    }
    if (difficulty != null && route.difficulty != difficulty) {
      return false;
    }
    if (elevation != null && route.elevationProfile != elevation) {
      return false;
    }
    if (surface != null && route.surfaceType != surface) {
      return false;
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      final nameMatches = route.name.toLowerCase().contains(q);
      final descMatches = route.description.toLowerCase().contains(q);
      if (!nameMatches && !descMatches) return false;
    }
    return true;
  }

  RouteFilter copyWith({
    OutdoorActivityType? activityType,
    bool clearActivityType = false,
    double? minDistanceKm,
    double? maxDistanceKm,
    bool clearDistance = false,
    RouteDifficulty? difficulty,
    bool clearDifficulty = false,
    RouteElevation? elevation,
    bool clearElevation = false,
    RouteSurface? surface,
    bool clearSurface = false,
    String? searchQuery,
  }) =>
      RouteFilter(
        activityType: clearActivityType ? null : (activityType ?? this.activityType),
        minDistanceKm: clearDistance ? null : (minDistanceKm ?? this.minDistanceKm),
        maxDistanceKm: clearDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
        difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
        elevation: clearElevation ? null : (elevation ?? this.elevation),
        surface: clearSurface ? null : (surface ?? this.surface),
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

