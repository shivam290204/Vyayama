import 'package:flutter/foundation.dart';

/// Centralized configuration for all external mapping, routing, and geocoding APIs.
///
/// Supports compile-time `--dart-define` overrides:
/// - `OSM_TILE_URL`: Custom tile server URL template.
/// - `OSM_USER_AGENT`: Custom User-Agent header string.
/// - `OVERPASS_API_URL`: Primary OpenStreetMap Overpass interpreter endpoint.
/// - `VALHALLA_API_URL`: OpenStreetMap Valhalla pedestrian routing endpoint.
/// - `NOMINATIM_API_URL`: OpenStreetMap Nominatim search and geocoding endpoint.
class MapApiConfig {
  MapApiConfig._();

  // ---------------------------------------------------------------------------
  // 1. OpenStreetMap Tile Server
  // ---------------------------------------------------------------------------

  /// Default OpenStreetMap community tile URL template.
  static const String defaultTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Default application User-Agent compliant with OSM tile & API usage policies.
  static const String defaultUserAgent = 'Vyayama/1.0 (com.vyayama.fitbuddy)';

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

  // ---------------------------------------------------------------------------
  // 2. OpenStreetMap Overpass API
  // ---------------------------------------------------------------------------

  /// Default primary Overpass API interpreter endpoint.
  static const String defaultOverpassUrl =
      'https://overpass-api.de/api/interpreter';

  /// Default public Overpass mirror endpoints for automatic failover.
  static const List<String> defaultOverpassMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  /// Resolved Overpass endpoint with `--dart-define` override support.
  static const String overpassUrl = String.fromEnvironment(
    'OVERPASS_API_URL',
    defaultValue: defaultOverpassUrl,
  );

  /// Effective list of Overpass endpoints (primary plus mirrors).
  static List<String> get overpassEndpoints {
    if (overpassUrl != defaultOverpassUrl) {
      // Custom endpoint configured; prioritize it, keep mirrors as secondary
      return [overpassUrl, ...defaultOverpassMirrors.where((m) => m != overpassUrl)];
    }
    return defaultOverpassMirrors;
  }

  // ---------------------------------------------------------------------------
  // 3. Valhalla Routing API
  // ---------------------------------------------------------------------------

  /// Default Valhalla pedestrian routing endpoint (OpenStreetMap public demo).
  static const String defaultValhallaUrl =
      'https://valhalla1.openstreetmap.de';

  /// Resolved Valhalla endpoint with `--dart-define` override support.
  static const String valhallaUrl = String.fromEnvironment(
    'VALHALLA_API_URL',
    defaultValue: defaultValhallaUrl,
  );

  // ---------------------------------------------------------------------------
  // 4. Nominatim Geocoding API
  // ---------------------------------------------------------------------------

  /// Default Nominatim geocoding & search endpoint.
  static const String defaultNominatimUrl =
      'https://nominatim.openstreetmap.org';

  /// Resolved Nominatim endpoint with `--dart-define` override support.
  static const String nominatimUrl = String.fromEnvironment(
    'NOMINATIM_API_URL',
    defaultValue: defaultNominatimUrl,
  );

  // ---------------------------------------------------------------------------
  // Public Community Infrastructure Detection & Release Warnings
  // ---------------------------------------------------------------------------

  /// Whether current tile config points to public community tile servers.
  static bool get isUsingPublicTileEndpoint =>
      tileUrl.contains('tile.openstreetmap.org');

  /// Whether current Overpass config points to public community servers.
  static bool get isUsingPublicOverpassEndpoint =>
      overpassUrl.contains('overpass-api.de') ||
      overpassUrl.contains('kumi.systems') ||
      overpassUrl.contains('private.coffee');

  /// Whether current Valhalla config points to public community demo server.
  static bool get isUsingPublicValhallaEndpoint =>
      valhallaUrl.contains('valhalla1.openstreetmap.de');

  /// Whether current Nominatim config points to public community server.
  static bool get isUsingPublicNominatimEndpoint =>
      nominatimUrl.contains('nominatim.openstreetmap.org');

  static bool _hasWarnedInRelease = false;

  /// Emits a clear diagnostic warning when a release build uses public community
  /// demo services without dedicated hosting configurations.
  static void warnIfPublicEndpointsInRelease() {
    if (kReleaseMode && !_hasWarnedInRelease) {
      final warnings = <String>[];
      if (isUsingPublicTileEndpoint) {
        warnings.add('Tile Server: $tileUrl (override with --dart-define=OSM_TILE_URL=...)');
      }
      if (isUsingPublicOverpassEndpoint) {
        warnings.add('Overpass API: $overpassUrl (override with --dart-define=OVERPASS_API_URL=...)');
      }
      if (isUsingPublicValhallaEndpoint) {
        warnings.add('Valhalla API: $valhallaUrl (override with --dart-define=VALHALLA_API_URL=...)');
      }
      if (isUsingPublicNominatimEndpoint) {
        warnings.add('Nominatim API: $nominatimUrl (override with --dart-define=NOMINATIM_API_URL=...)');
      }

      if (warnings.isNotEmpty) {
        _hasWarnedInRelease = true;
        debugPrint(
          '[WARNING][MapApiConfig] Production release build is configured with public community demo services:\n'
          '${warnings.map((w) => '  - $w').join('\n')}\n'
          'High-volume production distribution requires dedicated servers or commercial providers per OpenStreetMap usage policies.',
        );
      }
    }
  }

  /// Resets warning flag for test isolation.
  @visibleForTesting
  static void resetWarningFlagForTesting() {
    _hasWarnedInRelease = false;
  }
}
