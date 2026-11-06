import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';

/// Configurable endpoints for map services, read from `--dart-define` flags.
///
/// Supported flags:
/// - `TILE_URL_TEMPLATE`: Custom tile URL template.
/// - `OVERPASS_URLS`: Comma-separated list of Overpass interpreter URLs.
/// - `VALHALLA_URL`: Valhalla routing API endpoint.
/// - `NOMINATIM_URL`: Nominatim geocoding & search API endpoint.
///
/// Current public community servers are development defaults only.
/// Sensitive API keys must NEVER be stored in the repo or bundled .env files.
class MapServiceConfig {
  const MapServiceConfig._();

  /// Tile server URL template.
  /// Priority: `--dart-define=TILE_URL_TEMPLATE`, then `--dart-define=OSM_TILE_URL`, then default.
  static String get tileUrlTemplate {
    const fromTemplate = String.fromEnvironment('TILE_URL_TEMPLATE');
    if (fromTemplate.isNotEmpty) return fromTemplate;
    return MapApiConfig.tileUrl;
  }

  /// List of Overpass API endpoints in priority order.
  /// Priority: `--dart-define=OVERPASS_URLS` (comma-separated), then `--dart-define=OVERPASS_API_URL`, then default.
  static List<String> get overpassUrls {
    const fromDefine = String.fromEnvironment('OVERPASS_URLS');
    if (fromDefine.isNotEmpty) {
      return fromDefine
          .split(',')
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList();
    }
    return MapApiConfig.overpassEndpoints;
  }

  /// Valhalla pedestrian routing endpoint.
  /// Priority: `--dart-define=VALHALLA_URL`, then default.
  static String get valhallaUrl {
    const fromDefine = String.fromEnvironment('VALHALLA_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return MapApiConfig.valhallaUrl;
  }

  /// Nominatim geocoding endpoint.
  /// Priority: `--dart-define=NOMINATIM_URL`, then default.
  static String get nominatimUrl {
    const fromDefine = String.fromEnvironment('NOMINATIM_URL');
    if (fromDefine.isNotEmpty) return fromDefine;
    return MapApiConfig.nominatimUrl;
  }

  /// Whether current configuration points to public community endpoints.
  static bool get isUsingPublicEndpoints =>
      MapApiConfig.isUsingPublicTileEndpoint ||
      MapApiConfig.isUsingPublicOverpassEndpoint ||
      MapApiConfig.isUsingPublicValhallaEndpoint ||
      MapApiConfig.isUsingPublicNominatimEndpoint;
}
