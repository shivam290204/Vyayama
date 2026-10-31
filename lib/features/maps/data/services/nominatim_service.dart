import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';
import 'package:fitbuddy/features/maps/data/services/overpass_service.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:latlong2/latlong.dart';

/// A geocoded place result from Nominatim.
class NominatimResult {
  const NominatimResult({
    required this.placeId,
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  final int placeId;
  final String displayName;
  final double lat;
  final double lon;

  LatLng get latLng => LatLng(lat, lon);

  /// Shortened display name (first two comma-separated parts).
  String get shortName {
    final parts = displayName.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return parts.first.trim();
  }
}

/// Performs geographic place search using the OpenStreetMap Nominatim API.
///
/// [PRODUCTION NOTICE]:
/// The one-request-per-second limiter currently operates per application instance (in-memory).
/// It does NOT enforce a global aggregate limit across all active Vyayama users. For production
/// distribution, querying nominatim.openstreetmap.org directly from distributed client devices
/// violates the OpenStreetMap Nominatim Usage Policy. Production deployment requires either:
/// 1. A shared backend proxy (e.g., Supabase Edge Function or Cloud Run with shared Redis queue).
/// 2. A self-hosted Nominatim or Pelias instance.
/// 3. A commercial geocoding provider (e.g. Stadia Maps, Mapbox, Geocode Earth).
///
/// Complies with OpenStreetMap Nominatim Usage Policy for interactive evaluation:
/// - Max 1 request per second strictly enforced per client.
/// - Legitimate User-Agent header identifying Vyayama.
/// - In-memory LRU caching of results to prevent repeated queries.
/// - In-flight request joining to avoid concurrent duplicate requests.
/// - Intelligent rate-limit backoff on HTTP 429.
class NominatimService {
  NominatimService({
    RouteCache? cache,
    String? baseUrl,
    HttpClient Function()? clientFactory,
    this.retryBackoff = const Duration(milliseconds: 1500),
  })  : _cache = cache ?? RouteCache.instance,
        _baseUrl = baseUrl ?? MapApiConfig.nominatimUrl,
        _clientFactory = clientFactory ?? (() => HttpClient());

  final RouteCache _cache;
  final String _baseUrl;
  final HttpClient Function() _clientFactory;
  final Duration retryBackoff;

  static const Duration _timeout = Duration(seconds: 8);

  DateTime? _lastRequestTime;
  DateTime? _rateLimitedUntil;

  /// Active client tracking for cancellation.
  final Set<HttpClient> _activeClients = {};
  final Map<int, Set<HttpClient>> _generationClients = {};

  /// In-flight request deduplication map.
  final Map<String, Future<List<NominatimResult>>> _inFlightSearches = {};
  final Map<String, Future<List<OverpassPlace>>> _inFlightNearby = {};

  /// Cancels active in-flight network requests.
  /// If [requestId] is provided, cancels only clients for that generation.
  void cancelActiveRequests([int? requestId]) {
    if (requestId != null) {
      final clients = _generationClients.remove(requestId);
      if (clients != null) {
        for (final client in clients) {
          try {
            client.close(force: true);
          } catch (_) {}
          _activeClients.remove(client);
        }
      }
    } else {
      for (final client in _activeClients) {
        try {
          client.close(force: true);
        } catch (_) {}
      }
      _activeClients.clear();
      _generationClients.clear();
    }
  }

  /// Searches for [query] and returns up to 5 results.
  ///
  /// Returns empty list on error or no results.
  /// Joins duplicate in-flight requests and returns cached results when available.
  Future<List<NominatimResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cacheKey = RouteCache.buildNominatimSearchKey(trimmed);
    final cached = _cache.get<List<NominatimResult>>(cacheKey);
    if (cached != null) return cached;

    // Join duplicate in-flight requests
    if (_inFlightSearches.containsKey(cacheKey)) {
      return _inFlightSearches[cacheKey]!;
    }

    final future = _executeSearch(trimmed, cacheKey);
    _inFlightSearches[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inFlightSearches.remove(cacheKey);
    }
  }

  Future<List<NominatimResult>> _executeSearch(
    String query,
    String cacheKey,
  ) async {
    _checkRateLimit();
    await _throttle();

    HttpClient? client;
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '0',
      });

      client = _clientFactory()..userAgent = MapApiConfig.userAgent;
      _activeClients.add(client);

      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set('Accept-Language', 'en');
      final response = await request.close().timeout(_timeout);

      if (response.statusCode == 429) {
        _handleRateLimit();
        throw const RouteRateLimitException(
            'Nominatim rate limit reached. Please wait a moment.');
      }

      if (response.statusCode != 200) return [];

      final body = await response.transform(utf8.decoder).join();
      final results = _parse(body);
      _cache.set(cacheKey, results);
      return results;
    } on RouteRateLimitException {
      rethrow;
    } catch (_) {
      return [];
    } finally {
      if (client != null) {
        _activeClients.remove(client);
        try {
          client.close();
        } catch (_) {}
      }
    }
  }

  List<NominatimResult> _parse(String body) {
    try {
      final list = jsonDecode(body) as List<dynamic>;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return NominatimResult(
          placeId: (m['place_id'] as num).toInt(),
          displayName: m['display_name'] as String? ?? '',
          lat: double.parse(m['lat'] as String),
          lon: double.parse(m['lon'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Discovers real OpenStreetMap places (parks, gardens, recreation grounds)
  /// within [radiusMeters] around [center].
  ///
  /// Limits category requests to at most 2 per discovery to avoid abuse.
  /// Joins in-flight identical requests and respects rate limiting.
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
    int? requestId,
  }) async {
    final cacheKey = RouteCache.buildNominatimNearbyKey(center, radiusMeters);
    final cached = _cache.get<List<OverpassPlace>>(cacheKey);
    if (cached != null) return cached;

    if (_inFlightNearby.containsKey(cacheKey)) {
      return _inFlightNearby[cacheKey]!;
    }

    final future = _executeFindNearby(center, radiusMeters, cacheKey, requestId: requestId);
    _inFlightNearby[cacheKey] = future;

    try {
      return await future;
    } finally {
      _inFlightNearby.remove(cacheKey);
    }
  }

  Future<List<OverpassPlace>> _executeFindNearby(
    LatLng center,
    double radiusMeters,
    String cacheKey, {
    int? requestId,
  }) async {
    _checkRateLimit();

    // Lat/lon bounding box calculation: 1 deg lat ≈ 111,000 meters
    final clampedRadius = radiusMeters.clamp(300, 5000);
    final latDelta = clampedRadius / 111000.0;
    final cosLat = math.cos(center.latitudeInRad);
    final lonDelta =
        clampedRadius / (111000.0 * (cosLat.abs() > 0.01 ? cosLat.abs() : 1.0));

    final minLon = center.longitude - lonDelta;
    final maxLon = center.longitude + lonDelta;
    final minLat = center.latitude - latDelta;
    final maxLat = center.latitude + latDelta;
    final viewbox =
        '${minLon.toStringAsFixed(5)},${maxLat.toStringAsFixed(5)},${maxLon.toStringAsFixed(5)},${minLat.toStringAsFixed(5)}';

    // Prioritize 'park', only query 'recreation_ground' if needed
    final categories = ['park', 'recreation_ground'];
    final allPlaces = <OverpassPlace>[];
    final seenIds = <int>{};

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      await _throttle();

      HttpClient? client;
      try {
        final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
          'q': category,
          'format': 'json',
          'bounded': '1',
          'viewbox': viewbox,
          'limit': '8',
          'addressdetails': '1',
        });

        client = _clientFactory()..userAgent = MapApiConfig.userAgent;
        _activeClients.add(client);
        if (requestId != null) {
          _generationClients.putIfAbsent(requestId, () => {}).add(client);
        }

        final request = await client.getUrl(uri).timeout(_timeout);
        request.headers.set('Accept-Language', 'en');
        final response = await request.close().timeout(_timeout);

        if (response.statusCode == 429) {
          _handleRateLimit();
          break;
        }

        if (response.statusCode != 200) continue;

        final body = await response.transform(utf8.decoder).join();
        final places = parseNominatimPlaces(body, category);
        for (final p in places) {
          if (seenIds.add(p.id)) {
            allPlaces.add(p);
          }
        }

        // If primary category yielded sufficient candidates, stop without extra requests
        if (allPlaces.length >= 4) break;
      } catch (_) {
        // Continue to next category or return whatever found so far
      } finally {
        if (client != null) {
          _activeClients.remove(client);
          if (requestId != null) {
            _generationClients[requestId]?.remove(client);
          }
          try {
            client.close();
          } catch (_) {}
        }
      }
    }

    if (allPlaces.isNotEmpty) {
      _cache.set(cacheKey, allPlaces);
    }
    return allPlaces;
  }

  /// Parses Nominatim search JSON response into a list of [OverpassPlace] objects.
  static List<OverpassPlace> parseNominatimPlaces(
    String body, [
    String defaultType = 'park',
  ]) {
    try {
      final list = jsonDecode(body) as List<dynamic>;
      final results = <OverpassPlace>[];
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final id = (m['osm_id'] ?? m['place_id'] as num?)?.toInt() ?? 0;
        final latStr = m['lat'] as String?;
        final lonStr = m['lon'] as String?;
        if (latStr == null || lonStr == null) continue;
        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null) continue;
        if (!lat.isFinite || !lon.isFinite) continue;
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        final rawName = m['name'] as String? ?? '';
        final displayName = m['display_name'] as String? ?? '';
        final isNamed = rawName.trim().isNotEmpty;

        String name;
        if (isNamed) {
          name = rawName.trim();
        } else {
          final parts = displayName.split(',');
          if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
            final locality = parts.first.trim();
            name = '$locality Park';
          } else {
            name = 'Mapped Park';
          }
        }

        final type = (m['type'] as String?) ?? defaultType;
        final tags = <String, String>{
          'leisure': type,
          if (isNamed) 'name': name,
        };

        results.add(OverpassPlace(
          id: id,
          name: name,
          lat: lat,
          lon: lon,
          tags: tags,
          isNamed: isNamed,
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  void _checkRateLimit() {
    if (_rateLimitedUntil != null) {
      if (DateTime.now().isBefore(_rateLimitedUntil!)) {
        throw const RouteRateLimitException(
            'Nominatim rate limit cooldown active. Please wait a moment.');
      } else {
        _rateLimitedUntil = null;
      }
    }
  }

  void _handleRateLimit() {
    _rateLimitedUntil = DateTime.now().add(const Duration(seconds: 30));
  }

  Future<void> _throttle() async {
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      const minInterval = Duration(milliseconds: 1050); // > 1 sec per OSM policy
      if (elapsed < minInterval) {
        await Future<void>.delayed(minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}
