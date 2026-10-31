import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// A routed path returned by Valhalla.
class ValhallaRoute {
  const ValhallaRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  /// Analyzes the route geometry to determine if this is a genuine closed loop
  /// or an out-and-back retraced path.
  bool get isLoop => isClosedLoopGeometry(points, distanceMeters);

  /// Converts Valhalla route points to GpsPoint list for SavedRoute.
  List<GpsPoint> toGpsPoints() {
    final base = DateTime.now().subtract(const Duration(hours: 1));
    return points.asMap().entries.map((entry) {
      return GpsPoint(
        latitude: entry.value.latitude,
        longitude: entry.value.longitude,
        timestamp: base.add(Duration(seconds: entry.key * 3)),
        accuracy: 5.0,
      );
    }).toList();
  }
}

/// Calls the Valhalla routing API to compute real pedestrian routes.
///
/// Uses configurable endpoints, pedestrian costing, LRU caching,
/// and typed exception handling. Never generates synthetic route geometry.
class ValhallaService {
  ValhallaService({
    RouteCache? cache,
    String? baseUrl,
    HttpClient Function()? clientFactory,
    this.retryBackoff = const Duration(milliseconds: 1500),
  })  : _cache = cache ?? RouteCache.instance,
        _baseUrl = baseUrl ?? MapApiConfig.valhallaUrl,
        _clientFactory = clientFactory ?? (() => HttpClient());

  final RouteCache _cache;
  final String _baseUrl;
  final HttpClient Function() _clientFactory;
  final Duration retryBackoff;

  static const String _clientId = 'Vyayama';
  static const Duration _timeout = Duration(seconds: 12);

  final Set<HttpClient> _activeClients = {};
  final Map<int, Set<HttpClient>> _generationClients = {};

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

  /// Requests a pedestrian route from [origin] through [waypoints].
  ///
  /// Throws [RouteRateLimitException] on HTTP 429.
  /// Throws [ValhallaRoutingException] on server errors.
  /// Throws [RouteNetworkException] on connectivity or timeout failure.
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
    int? requestId,
  }) async {
    if (waypoints.isEmpty) return null;

    // Validate coordinates
    if (!origin.latitude.isFinite || !origin.longitude.isFinite) return null;
    for (final wp in waypoints) {
      if (!wp.latitude.isFinite || !wp.longitude.isFinite) return null;
    }

    final cacheKey = RouteCache.buildValhallaKey(origin, waypoints);
    final cached = _cache.get<ValhallaRoute>(cacheKey);
    if (cached != null) return cached;

    final locations = <Map<String, dynamic>>[
      _location(origin),
      ...waypoints.map(_location),
    ];

    final body = jsonEncode({
      'locations': locations,
      'costing': 'pedestrian',
      'costing_options': {
        'pedestrian': {
          'walking_speed': 5.1, // km/h
          'max_hiking_difficulty': 5,
        },
      },
      'directions_options': {'units': 'km'},
    });

    for (int attempt = 0; attempt <= 1; attempt++) {
      HttpClient? client;
      try {
        client = _clientFactory()..userAgent = MapApiConfig.userAgent;
        _activeClients.add(client);
        if (requestId != null) {
          _generationClients.putIfAbsent(requestId, () => {}).add(client);
        }

        final uri = Uri.parse('$_baseUrl/route');
        final request = await client.postUrl(uri).timeout(_timeout);
        request.headers
            .set(HttpHeaders.contentTypeHeader, 'application/json');
        request.headers.set('X-Client-Id', _clientId);
        request.write(body);

        final response = await request.close().timeout(_timeout);

        if (response.statusCode == 429) {
          throw const RouteRateLimitException(
              'Valhalla routing rate limit reached. Please wait a moment.');
        }

        // 400/404: Unroutable point across barrier/water. Never retry.
        if (response.statusCode == 400 || response.statusCode == 404) {
          return null;
        }

        // 5xx: Server error. Retry at most once on transient server error.
        if (response.statusCode >= 500) {
          if (attempt == 0) {
            await Future<void>.delayed(retryBackoff);
            continue;
          }
          throw ValhallaRoutingException(
              'Valhalla routing service returned server error (${response.statusCode}).');
        }

        if (response.statusCode != 200) {
          throw ValhallaRoutingException(
              'Routing service returned unexpected status (${response.statusCode}).');
        }

        final responseBody = await response.transform(utf8.decoder).join();
        final parsed = _parseRoute(responseBody);
        if (parsed != null) {
          _cache.set(cacheKey, parsed);
        }
        return parsed;
      } on RouteRateLimitException {
        rethrow;
      } on SocketException catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(retryBackoff);
          continue;
        }
        throw const RouteNetworkException();
      } on TimeoutException catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(retryBackoff);
          continue;
        }
        throw const RouteNetworkException(
            'Routing service request timed out. Please try again.');
      } on RouteDiscoveryException {
        rethrow;
      } catch (e) {
        throw ValhallaRoutingException('Routing failed: $e');
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
    return null;
  }

  ValhallaRoute? _parseRoute(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final trip = json['trip'] as Map<String, dynamic>?;
      if (trip == null) return null;

      final summary = trip['summary'] as Map<String, dynamic>?;
      final lengthKm = (summary?['length'] as num?)?.toDouble() ?? 0.0;
      final durationSec = (summary?['time'] as num?)?.toDouble() ?? 0.0;

      final legs = trip['legs'] as List<dynamic>? ?? [];
      final allPoints = <LatLng>[];

      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final shape = legMap['shape'] as String?;
        if (shape != null) {
          allPoints.addAll(_decodePolyline6(shape));
        }
      }

      // Essential routing validation: valid geometry points and realistic distance
      if (allPoints.length < 2) return null;
      if (lengthKm <= 0.0) return null;

      for (final pt in allPoints) {
        if (!pt.latitude.isFinite || !pt.longitude.isFinite) return null;
        if (pt.latitude < -90 || pt.latitude > 90 || pt.longitude < -180 || pt.longitude > 180) {
          return null;
        }
      }

      return ValhallaRoute(
        points: allPoints,
        distanceMeters: lengthKm * 1000.0,
        durationSeconds: durationSec,
      );
    } catch (e) {
      throw ValhallaRoutingException('Failed to parse route response: $e');
    }
  }

  /// Exposed for unit testing only.
  @visibleForTesting
  ValhallaRoute? testParseRoute(String body) => _parseRoute(body);

  Map<String, dynamic> _location(LatLng ll) => {
        'lat': ll.latitude,
        'lon': ll.longitude,
        'type': 'break',
      };

  /// Decodes a Valhalla/OSRM encoded polyline (precision 6).
  List<LatLng> _decodePolyline6(String encoded) {
    final result = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result2 & 1) != 0 ? ~(result2 >> 1) : (result2 >> 1);
      lat += dlat;

      shift = 0;
      result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result2 & 1) != 0 ? ~(result2 >> 1) : (result2 >> 1);
      lng += dlng;

      result.add(LatLng(lat / 1e6, lng / 1e6));
    }

    return result;
  }
}

/// Haversine distance between two LatLng points in meters.
double haversineDistance(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final sinLat = math.sin(dLat / 2);
  final sinLon = math.sin(dLon / 2);
  final x = sinLat * sinLat +
      math.cos(a.latitude * math.pi / 180) *
          math.cos(b.latitude * math.pi / 180) *
          sinLon *
          sinLon;
  return 2 * earthRadius * math.atan2(math.sqrt(x), math.sqrt(1 - x));
}
