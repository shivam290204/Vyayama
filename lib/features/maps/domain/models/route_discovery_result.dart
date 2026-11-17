import 'dart:collection';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/foundation.dart';

/// Categorized reasons why route discovery returned no routes.
enum EmptyReason {
  /// Routes were successfully discovered.
  none,

  /// No valid GPS or map center was available.
  noLocation,

  /// Overpass or network timed out (including Overpass server-side remark timeouts).
  serviceTimeout,

  /// Overpass, Nominatim, or network returned an unexpected server error.
  serviceError,

  /// Overpass or Nominatim rate limited the client (HTTP 429).
  rateLimited,

  /// Overpass and Nominatim both succeeded but found 0 mapped features.
  noPlacesFound,

  /// Places were found, but none met candidate waypoint criteria.
  noCandidates,

  /// Valhalla routing failed or returned null for all candidates.
  allRoutesFailed,

  /// Valhalla produced routes, but all were dropped by filters (too short, too few points, duplicate).
  allRoutesFiltered,

  /// Every stage ran OK with valid data, but no routes could be formed.
  genuineEmpty,
}

/// Source of the geographic search center.
enum SearchCenterSource {
  /// Verified live device GPS.
  userGps,

  /// Explicit user map tap or pan.
  mapCenter,

  /// Hardcoded or synthetic fallback center.
  fallback,

  /// No search center available.
  none,
}

/// Detailed per-stage diagnostics for a route discovery run.
@immutable
class RouteDiscoveryDiagnostics {
  const RouteDiscoveryDiagnostics({
    required this.timestamp,
    required this.searchCenterSource,
    required this.hasValidNonFallbackLocation,
    this.roundedLat,
    this.roundedLon,
    this.searchRadiusMeters = 5000,
    required this.overpassStatus,
    this.overpassElementCount = 0,
    this.overpassRemark,
    this.nominatimCount = 0,
    this.nominatimError,
    this.candidatesCount = 0,
    this.valhallaAttempts = 0,
    this.valhallaSuccesses = 0,
    this.valhallaNulls = 0,
    this.valhallaErrors = 0,
    this.droppedTooShort = 0,
    this.droppedTooFewPoints = 0,
    this.droppedDuplicate = 0,
    required this.finalRouteCount,
    required this.emptyReason,
  });

  /// Timestamp when discovery was performed.
  final DateTime timestamp;

  /// Source of the search center coordinate.
  final SearchCenterSource searchCenterSource;

  /// Whether the coordinate is from a real GPS fix or manual center (not a fallback).
  final bool hasValidNonFallbackLocation;

  /// Latitude rounded to 2 decimal places for privacy.
  final double? roundedLat;

  /// Longitude rounded to 2 decimal places for privacy.
  final double? roundedLon;

  /// Search radius in meters.
  final double searchRadiusMeters;

  /// Overpass stage status ('OK', 'timeout', 'error', 'skipped').
  final String overpassStatus;

  /// Number of raw elements returned by Overpass.
  final int overpassElementCount;

  /// Server-side remark from Overpass JSON (e.g. timeout or OOM).
  final String? overpassRemark;

  /// Number of places returned by Nominatim.
  final int nominatimCount;

  /// Error message from Nominatim if any occurred.
  final String? nominatimError;

  /// Number of candidate waypoints selected for Valhalla routing.
  final int candidatesCount;

  /// Total Valhalla routing requests attempted.
  final int valhallaAttempts;

  /// Total Valhalla routes successfully generated.
  final int valhallaSuccesses;

  /// Total Valhalla routes that returned null (unroutable).
  final int valhallaNulls;

  /// Total Valhalla routing requests that threw exceptions.
  final int valhallaErrors;

  /// Routes dropped because distance was under 300m.
  final int droppedTooShort;

  /// Routes dropped because point count was under threshold.
  final int droppedTooFewPoints;

  /// Routes dropped because of OSM pair or geometric duplication.
  final int droppedDuplicate;

  /// Final valid routes returned to the caller.
  final int finalRouteCount;

  /// High-level classified outcome reason.
  final EmptyReason emptyReason;

  /// Helper to safely round a coordinate to 2 decimal places without exposing raw GPS.
  static double? roundCoord(double? val) {
    if (val == null || !val.isFinite) return null;
    return (val * 100).roundToDouble() / 100;
  }

  /// Whether this run was a failure requiring a retry vs a genuinely empty area.
  bool get isServiceFailure =>
      emptyReason == EmptyReason.serviceTimeout ||
      emptyReason == EmptyReason.serviceError ||
      emptyReason == EmptyReason.rateLimited ||
      emptyReason == EmptyReason.allRoutesFailed;

  /// Formats a complete plain-text diagnostics report suitable for clipboard copying.
  String toPlainText() {
    final buf = StringBuffer();
    buf.writeln('=== Route Discovery Diagnostics ===');
    buf.writeln('Timestamp: ${timestamp.toUtc().toIso8601String()}');
    buf.writeln('Empty Reason: ${emptyReason.name}');
    buf.writeln('');

    buf.writeln('1. SEARCH CENTER');
    buf.writeln('   • Source: ${searchCenterSource.name}');
    buf.writeln('   • Non-Fallback Valid Position: $hasValidNonFallbackLocation');
    if (roundedLat != null && roundedLon != null) {
      buf.writeln('   • Search Center (approx): $roundedLat, $roundedLon');
    }
    buf.writeln('   • Search Radius: ${searchRadiusMeters.round()} m');
    buf.writeln('');

    buf.writeln('2. OVERPASS STAGE');
    buf.writeln('   • Status: $overpassStatus');
    buf.writeln('   • Raw Elements: $overpassElementCount');
    if (overpassRemark != null && overpassRemark!.isNotEmpty) {
      buf.writeln('   • Server Remark: $overpassRemark');
    }
    buf.writeln('');

    buf.writeln('3. NOMINATIM STAGE');
    buf.writeln('   • Places Found: $nominatimCount');
    if (nominatimError != null) {
      buf.writeln('   • Error: $nominatimError');
    }
    buf.writeln('');

    buf.writeln('4. CANDIDATES & ROUTING');
    buf.writeln('   • Candidates Selected: $candidatesCount');
    buf.writeln('   • Valhalla Attempts: $valhallaAttempts');
    buf.writeln('   • Valhalla Successes: $valhallaSuccesses');
    buf.writeln('   • Valhalla Nulls: $valhallaNulls');
    buf.writeln('   • Valhalla Errors: $valhallaErrors');
    buf.writeln('');

    buf.writeln('5. FILTERS APPLIED');
    buf.writeln('   • Dropped (Distance < 300m): $droppedTooShort');
    buf.writeln('   • Dropped (Too Few Points): $droppedTooFewPoints');
    buf.writeln('   • Dropped (Duplicate): $droppedDuplicate');
    buf.writeln('   • Final Routes Count: $finalRouteCount');
    buf.writeln('===================================');
    return buf.toString();
  }
}

/// Rich result of route discovery containing both the routes list and per-stage diagnostics.
///
/// Implements [List<SavedRoute>] so existing callers expecting a list continue to work
/// without breaking changes, while enabling inspection of [diagnostics] and [emptyReason].
class RouteDiscoveryResult with ListMixin<SavedRoute> implements List<SavedRoute> {
  RouteDiscoveryResult({
    required List<SavedRoute> routes,
    required this.diagnostics,
  }) : _routes = List<SavedRoute>.unmodifiable(routes);

  /// Empty result factory for convenience.
  factory RouteDiscoveryResult.empty({
    required RouteDiscoveryDiagnostics diagnostics,
  }) {
    return RouteDiscoveryResult(routes: const [], diagnostics: diagnostics);
  }

  final List<SavedRoute> _routes;

  /// Underlying list of discovered routes.
  List<SavedRoute> get routes => _routes;

  /// Full diagnostics breakdown.
  final RouteDiscoveryDiagnostics diagnostics;

  /// Quick access to the empty reason.
  EmptyReason get emptyReason => diagnostics.emptyReason;

  @override
  int get length => _routes.length;

  @override
  set length(int newLength) =>
      throw UnsupportedError('RouteDiscoveryResult is unmodifiable');

  @override
  SavedRoute operator [](int index) => _routes[index];

  @override
  void operator []=(int index, SavedRoute value) =>
      throw UnsupportedError('RouteDiscoveryResult is unmodifiable');
}
