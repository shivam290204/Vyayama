// lib/features/maps/data/services/overpass_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:latlong2/latlong.dart';

/// Result from an Overpass query — a named geographic feature that can serve
/// as a route waypoint or area of interest.
class OverpassPlace {
  const OverpassPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.tags,
  });

  final int id;
  final String name;
  final double lat;
  final double lon;
  final Map<String, String> tags;

  LatLng get latLng => LatLng(lat, lon);

  bool get isPark =>
      tags['leisure'] == 'park' ||
      tags['leisure'] == 'recreation_ground' ||
      tags['landuse'] == 'recreation_ground';

  bool get isTrail =>
      tags['highway'] == 'path' ||
      tags['highway'] == 'footway' ||
      tags['highway'] == 'track' ||
      tags['route'] == 'hiking' ||
      tags['route'] == 'foot';

  @override
  String toString() => 'OverpassPlace($name at $lat,$lon)';
}

/// Queries the OpenStreetMap Overpass API for real nearby geographic features.
///
/// Uses the public Overpass API. Implements caching to avoid excessive requests.
/// Rate-limits to at most 1 request per 5 seconds.
class OverpassService {
  OverpassService({RouteCache? cache}) : _cache = cache ?? RouteCache.instance;

  static const String _endpoint = 'https://overpass-api.de/api/interpreter';
  static const String _userAgent = 'Vyayama/1.0 (com.vyayama.fitbuddy)';
  static const Duration _timeout = Duration(seconds: 15);
  static const int _maxResults = 20;

  final RouteCache _cache;
  DateTime? _lastRequestTime;

  /// Finds named parks, recreation grounds, trails and footways within [radiusMeters]
  /// of [center]. Returns empty list on network failure or if none found.
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
  }) async {
    final cacheKey = 'overpass_${center.latitude.toStringAsFixed(3)}_'
        '${center.longitude.toStringAsFixed(3)}_${radiusMeters.round()}';

    final cached = _cache.get<List<OverpassPlace>>(cacheKey);
    if (cached != null) return cached;

    await _throttle();

    final lat = center.latitude;
    final lon = center.longitude;
    final r = radiusMeters.round();

    // Overpass QL: find named parks, recreation grounds, named footways/paths
    final query = '''
[out:json][timeout:12];
(
  node["leisure"~"^(park|recreation_ground)\$"]["name"](around:$r,$lat,$lon);
  way["leisure"~"^(park|recreation_ground)\$"]["name"](around:$r,$lat,$lon);
  way["highway"~"^(footway|path|pedestrian|track)\$"]["name"](around:$r,$lat,$lon);
  relation["route"~"^(hiking|foot)\$"]["name"](around:$r,$lat,$lon);
);
out center $_maxResults;
''';

    try {
      final client = HttpClient();
      client.userAgent = _userAgent;
      final uri = Uri.parse(_endpoint);
      final request = await client.postUrl(uri).timeout(_timeout);
      request.headers.set(
          HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
      request.write('data=${Uri.encodeComponent(query)}');
      final response = await request.close().timeout(_timeout);

      if (response.statusCode == 429) {
        // Rate limited — return empty, don't cache
        client.close();
        return [];
      }

      if (response.statusCode != 200) {
        client.close();
        return [];
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final places = _parseOverpassResponse(body);
      _cache.set(cacheKey, places);
      return places;
    } catch (_) {
      return [];
    }
  }

  List<OverpassPlace> _parseOverpassResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final elements = json['elements'] as List<dynamic>? ?? [];
      final results = <OverpassPlace>[];

      for (final element in elements) {
        final map = element as Map<String, dynamic>;
        final tags = (map['tags'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString()));

        final name = tags['name'] ?? '';
        if (name.isEmpty) continue;

        double? lat;
        double? lon;

        if (map['type'] == 'node') {
          lat = (map['lat'] as num?)?.toDouble();
          lon = (map['lon'] as num?)?.toDouble();
        } else if (map['center'] != null) {
          // way or relation with center
          final center = map['center'] as Map<String, dynamic>;
          lat = (center['lat'] as num?)?.toDouble();
          lon = (center['lon'] as num?)?.toDouble();
        }

        if (lat == null || lon == null) continue;

        results.add(OverpassPlace(
          id: (map['id'] as num).toInt(),
          name: name,
          lat: lat,
          lon: lon,
          tags: tags,
        ));
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  Future<void> _throttle() async {
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      const minInterval = Duration(seconds: 5);
      if (elapsed < minInterval) {
        await Future<void>.delayed(minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}
