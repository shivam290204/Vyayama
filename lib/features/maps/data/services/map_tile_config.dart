import 'package:flutter/foundation.dart';
import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';

export 'package:fitbuddy/features/maps/data/services/map_api_config.dart';

/// Centralized configuration for OpenStreetMap and raster map tile sources.
///
/// Backwards-compatible facade over [MapApiConfig].
class MapTileConfig {
  MapTileConfig._();

  /// Default OpenStreetMap community tile URL template.
  static const String defaultTileUrl = MapApiConfig.defaultTileUrl;

  /// Default application User-Agent compliant with OSM tile usage policy.
  static const String defaultUserAgent = MapApiConfig.defaultUserAgent;

  /// Resolved tile URL template with `--dart-define` override support.
  static String get tileUrl => MapApiConfig.tileUrl;

  /// Resolved User-Agent with `--dart-define` override support.
  static String get userAgent => MapApiConfig.userAgent;

  /// OpenStreetMap copyright and terms URL for attribution linking.
  static const String osmCopyrightUrl = MapApiConfig.osmCopyrightUrl;

  /// Whether the current configuration points to public community OSM tile infrastructure.
  static bool get isUsingPublicCommunityEndpoint =>
      MapApiConfig.isUsingPublicTileEndpoint;

  /// Emits a clear diagnostic warning when a release build uses public community endpoints.
  static void warnIfPublicTileServerInRelease() {
    MapApiConfig.warnIfPublicEndpointsInRelease();
  }

  /// Resets warning flag for test isolation.
  @visibleForTesting
  static void resetWarningFlagForTesting() {
    // ignore: invalid_use_of_visible_for_testing_member
    MapApiConfig.resetWarningFlagForTesting();
  }
}
