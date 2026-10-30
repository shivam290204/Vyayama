import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:latlong2/latlong.dart';

/// Result from an Overpass query — a genuine geographic feature (named or unnamed)
/// that can serve as a route waypoint or area of interest.
class OverpassPlace {
  const OverpassPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.tags,
    this.isNamed = true,
  });

  final int id;
  final String name;
  final double lat;
  final double lon;
  final Map<String, String> tags;
  final bool isNamed;

  LatLng get latLng => LatLng(lat, lon);

  bool get isPark =>
      tags['leisure'] == 'park' ||
      tags['leisure'] == 'recreation_ground' ||
      tags['leisure'] == 'nature_reserve' ||
      tags['landuse'] == 'recreation_ground';

  bool get isTrail =>
      tags['highway'] == 'path' ||
      tags['highway'] == 'footway' ||
      tags['highway'] == 'track' ||
      tags['route'] == 'hiking' ||
      tags['route'] == 'foot';

  bool get isHikingRoute =>
      tags['route'] == 'hiking' ||
      tags['highway'] == 'track' ||
      tags['sac_scale'] != null;

  /// Returns a truthful descriptive name derived from OSM tags without inventing fictional proper nouns.
  static String deriveDescriptiveName(Map<String, String> tags) {
    final rawName = tags['name'];
    if (rawName != null && rawName.trim().isNotEmpty) {
      return rawName.trim();
    }
    if (tags['route'] == 'hiking') return 'Mapped Hiking Trail';
    if (tags['leisure'] == 'nature_reserve') return 'Nature Reserve Area';
    if (tags['leisure'] == 'park') return 'Park Pathway';
    if (tags['leisure'] == 'recreation_ground') return 'Recreation Ground Path';
    if (tags['highway'] == 'path') return 'Pedestrian Path';
    if (tags['highway'] == 'footway') return 'Mapped Footway';
    if (tags['highway'] == 'track') return 'Outdoor Walking Track';
    if (tags['highway'] == 'pedestrian') return 'Pedestrian Way';
    return 'Mapped Walking Path';
  }

  @override
  String toString() => 'OverpassPlace($name at $lat,$lon, isNamed: $isNamed)';
}

/// Queries the OpenStreetMap Overpass API for real nearby geographic features.
///
/// Uses public Overpass API mirrors with automatic failover.
/// Implements TTL caching and request throttling to avoid excessive server requests.
class OverpassService {
  OverpassService({
    RouteCache? cache,
    String? endpoint,
    List<String>? endpoints,
  })  : _cache = cache ?? RouteCache.instance,
        _endpoints = endpoints ??
            (endpoint != null
                ? [endpoint]
                : defaultEndpoints);

  static const List<String> defaultEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  final List<String> _endpoints;
  static const String _userAgent = 'Vyayama/1.0 (com.vyayama.fitbuddy)';
  static const Duration _timeout = Duration(seconds: 6);
  static const int _maxResults = 50;

  final RouteCache _cache;
  DateTime? _lastRequestTime;

  /// Finds parks, recreation grounds, trails, footways, and hiking routes within [radiusMeters]
  /// of [center].
  ///
  /// Throws [RouteRateLimitException] on HTTP 429.
  /// Throws [OverpassServiceException] on server error (HTTP 5xx).
  /// Throws [RouteNetworkException] on connection failure or timeout.
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

    // Overpass QL: index-accelerated exact tag matching for parks, recreation grounds,
    // walking paths, footways, pedestrian roads, tracks, and hiking relations.
    final query = '''
[out:json][timeout:6];
(
  node["leisure"="park"](around:$r,$lat,$lon);
  way["leisure"="park"](around:$r,$lat,$lon);
  node["leisure"="recreation_ground"](around:$r,$lat,$lon);
  way["leisure"="recreation_ground"](around:$r,$lat,$lon);
  node["leisure"="nature_reserve"](around:$r,$lat,$lon);
  way["leisure"="nature_reserve"](around:$r,$lat,$lon);
  way["leisure"="garden"](around:$r,$lat,$lon);
  way["highway"="footway"](around:$r,$lat,$lon);
  way["highway"="pedestrian"](around:$r,$lat,$lon);
  way["highway"="path"](around:$r,$lat,$lon);
  way["highway"="track"](around:$r,$lat,$lon);
  relation["route"="hiking"](around:$r,$lat,$lon);
  relation["route"="foot"](around:$r,$lat,$lon);
);
out center $_maxResults;
''';

    RouteDiscoveryException? lastException;

    for (final ep in _endpoints) {
      HttpClient? client;
      try {
        client = HttpClient()..userAgent = _userAgent;
        final uri = Uri.parse(ep);
        final request = await client.postUrl(uri).timeout(_timeout);
        request.headers.set(
            HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
        request.write('data=${Uri.encodeComponent(query)}');
        final response = await request.close().timeout(_timeout);

        if (response.statusCode == 429) {
          lastException = const RouteRateLimitException();
          continue;
        }

        if (response.statusCode >= 500) {
          lastException = OverpassServiceException(
              'OpenStreetMap service returned server error (${response.statusCode}).');
          continue;
        }

        if (response.statusCode != 200) {
          lastException = OverpassServiceException(
              'OpenStreetMap service returned unexpected status (${response.statusCode}).');
          continue;
        }

        final body = await response.transform(utf8.decoder).join();
        final places = parseOverpassResponse(body);
        _cache.set(cacheKey, places);
        return places;
      } on SocketException catch (_) {
        lastException = const RouteNetworkException();
      } on TimeoutException catch (_) {
        lastException = const RouteNetworkException(
            'Connection to OpenStreetMap service timed out. Please try again.');
      } on RouteDiscoveryException catch (e) {
        lastException = e;
      } catch (e) {
        lastException =
            OverpassServiceException('Failed to process OpenStreetMap data: $e');
      } finally {
        client?.close();
      }
    }

    if (lastException != null) {
      throw lastException;
    }
    return [];
  }

  /// Parses Overpass JSON response into a list of [OverpassPlace] objects.
  List<OverpassPlace> parseOverpassResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final elements = json['elements'] as List<dynamic>? ?? [];
      final results = <OverpassPlace>[];

      for (final element in elements) {
        final map = element as Map<String, dynamic>;
        final tags = (map['tags'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString()));

        final rawName = tags['name'];
        final isNamed = rawName != null && rawName.trim().isNotEmpty;
        final name = OverpassPlace.deriveDescriptiveName(tags);

        double? lat;
        double? lon;

        if (map['type'] == 'node') {
          lat = (map['lat'] as num?)?.toDouble();
          lon = (map['lon'] as num?)?.toDouble();
        } else if (map['center'] != null) {
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
          isNamed: isNamed,
        ));
      }

      return results;
    } catch (e) {
      throw OverpassServiceException('Invalid OpenStreetMap response format: $e');
    }
  }

  Future<void> _throttle() async {
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      const minInterval = Duration(seconds: 4);
      if (elapsed < minInterval) {
        await Future<void>.delayed(minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}
