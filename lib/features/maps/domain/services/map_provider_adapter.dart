import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';
import 'package:fitbuddy/features/maps/data/services/map_service_config.dart';

/// Provider adapter interface allowing seamless switching of map tiles
/// and routing backends without UI modifications.
abstract class MapProviderAdapter {
  const MapProviderAdapter();

  /// Unique machine identifier for this provider.
  String get id;

  /// Human-readable label for settings or diagnostics.
  String get displayName;

  /// Tile URL template compatible with `flutter_map` [TileLayer].
  String get tileUrlTemplate;

  /// HTTP headers required for tile requests (e.g. User-Agent).
  Map<String, String> get tileHeaders;

  /// Plain-text copyright and attribution notice required by provider terms.
  String get attributionText;

  /// Attribution terms / improvement URL.
  String get attributionUrl;

  /// Whether this provider is configured and available for use.
  bool get isEnabled;
}

/// Default OpenStreetMap provider adapter using community infrastructure.
class OsmMapProviderAdapter extends MapProviderAdapter {
  const OsmMapProviderAdapter();

  @override
  String get id => 'osm';

  @override
  String get displayName => 'OpenStreetMap (Community)';

  @override
  String get tileUrlTemplate => MapServiceConfig.tileUrlTemplate;

  @override
  Map<String, String> get tileHeaders => {
        'User-Agent': MapApiConfig.userAgent,
      };

  @override
  String get attributionText => '© OpenStreetMap contributors';

  @override
  String get attributionUrl => MapApiConfig.osmCopyrightUrl;

  @override
  bool get isEnabled => true;
}

/// Optional Mapbox provider adapter (disabled by default).
///
/// **Citations & Documentation Reference**:
/// - Mapbox Raster Tiles API: https://docs.mapbox.com/api/maps/raster-tiles/
///   Format: `https://api.mapbox.com/styles/v1/{username}/{style_id}/tiles/256/{z}/{x}/{y}@2x?access_token={token}`
/// - flutter_map Mapbox Integration: https://docs.fleaflet.dev/layers/tile-layer
/// - Mapbox Directions API (Walking): https://docs.mapbox.com/api/navigation/directions/
/// - Mapbox Attribution Requirements: https://docs.mapbox.com/help/getting-started/attribution/
///   Requires: Mapbox logo / text + "© Mapbox" + "© OpenStreetMap" + link to "Improve this map".
/// - Mapbox Free Tier & Pricing (as of 2024-2026):
///   - 50,000 raster tile map loads / month free (then $0.50 per 1,000 requests).
///   - 100,000 Directions requests / month free (then $0.50 per 1,000 requests).
///   - Mobile SDKs: 25,000 monthly active users (MAU) free.
///
/// **Security & Token Exposure Analysis**:
/// - Public client tokens (`pk.ey...`) embedded in client binaries or apps can be extracted
///   via reverse engineering or network inspection.
/// - **Token Restrictions Required**: In the Mapbox Account Dashboard:
///   1. Restrict token by Android Package Name (`com.vyayama.fitbuddy`) and SHA-256 certificate fingerprint.
///   2. Restrict token by iOS Bundle Identifier (`com.vyayama.fitbuddy`).
///   3. Scope restriction: grant ONLY `styles:tiles`, `styles:read`, and `directions:read` (never secret or write scopes).
///   4. Billing controls: configure monthly spend limits and budget alerts at 50% and 85% free tier thresholds.
/// - **Token Injection**: Must be passed via `--dart-define=MAPBOX_ACCESS_TOKEN=pk.xxx` and
///   `--dart-define=ENABLE_MAPBOX=true`. NEVER hardcode in source files or git-tracked `.env`.
class MapboxProviderAdapter extends MapProviderAdapter {
  const MapboxProviderAdapter({
    this.styleId = 'outdoors-v12',
    this.username = 'mapbox',
  });

  /// Mapbox style ID (e.g. `outdoors-v12`, `streets-v12`).
  final String styleId;

  /// Mapbox username / owner (default: `mapbox`).
  final String username;

  static const String _token = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static const bool _enabledFlag = bool.fromEnvironment('ENABLE_MAPBOX', defaultValue: false);

  @override
  String get id => 'mapbox';

  @override
  String get displayName => 'Mapbox ($styleId)';

  @override
  String get tileUrlTemplate =>
      'https://api.mapbox.com/styles/v1/$username/$styleId/tiles/256/{z}/{x}/{y}@2x?access_token=$_token';

  @override
  Map<String, String> get tileHeaders => const {};

  @override
  String get attributionText => '© Mapbox © OpenStreetMap Improve this map';

  @override
  String get attributionUrl => 'https://www.mapbox.com/about/maps/';

  @override
  bool get isEnabled => _enabledFlag && _token.isNotEmpty;

  /// Access token string (empty if not configured).
  String get accessToken => _token;
}
