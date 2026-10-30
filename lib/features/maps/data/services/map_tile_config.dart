import 'package:flutter/foundation.dart';

/// Centralized configuration for OpenStreetMap and raster map tile sources.
///
/// Supports compile-time `--dart-define` overrides:
/// - `OSM_TILE_URL`: Custom tile server URL template (e.g. self-hosted cache, Mapbox, Stadia).
/// - `OSM_USER_AGENT`: Custom User-Agent header string compliant with tile usage policies.
class MapTileConfig {
  MapTileConfig._();

  /// Default OpenStreetMap community tile URL template.
  static const String defaultTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Default application User-Agent compliant with OSM tile usage policy.
  static const String defaultUserAgent = 'com.vyayama.fitbuddy';

  /// Resolved tile URL template with `--dart-define` override support.
  static const String tileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: defaultTileUrl,
  );

  /// Resolved User-Agent with `--dart-define` override support.
  static const String userAgent = String.fromEnvironment(
    'OSM_USER_AGENT',
    defaultValue: defaultUserAgent,
  );

  /// OpenStreetMap copyright and terms URL for attribution linking.
  static const String osmCopyrightUrl = 'https://openstreetmap.org/copyright';

  /// Whether the current configuration points to public community OSM tile infrastructure.
  static bool get isUsingPublicCommunityEndpoint =>
      tileUrl.contains('tile.openstreetmap.org');

  static bool _hasWarnedInRelease = false;

  /// Emits a clear diagnostic warning when a release build uses the public OSM community tile servers.
  /// Per the OSM Tile Usage Policy, high-volume production distribution requires dedicated tile hosting.
  static void warnIfPublicTileServerInRelease() {
    if (kReleaseMode && isUsingPublicCommunityEndpoint && !_hasWarnedInRelease) {
      _hasWarnedInRelease = true;
      debugPrint(
        '[WARNING][MapTileConfig] Production release build is configured with the public OpenStreetMap '
        'community tile servers ($tileUrl). High-volume apps must provide a dedicated tile server or '
        'commercial tile provider via --dart-define=OSM_TILE_URL=... per the OpenStreetMap Tile Usage Policy.',
      );
    }
  }

  /// Resets warning flag for test isolation.
  @visibleForTesting
  static void resetWarningFlagForTesting() {
    _hasWarnedInRelease = false;
  }
}
