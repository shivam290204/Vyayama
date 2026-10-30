// lib/features/maps/data/services/valhalla_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
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
/// Uses the public Valhalla demo server: https://valhalla1.openstreetmap.de
/// Not suitable for high-volume production use.
///
/// Endpoints:
///   POST https://valhalla1.openstreetmap.de/route
///
/// Costing: pedestrian (for walking, running, hiking)
class ValhallaService {
  ValhallaService();

  static const String _baseUrl = 'https://valhalla1.openstreetmap.de';
  static const String _userAgent = 'Vyayama/1.0 (com.vyayama.fitbuddy)';
  static const String _clientId = 'vyayama';
  static const Duration _timeout = Duration(seconds: 20);

  /// Requests a pedestrian route from [origin] through [waypoints] and back.
  /// For a circular loop, the last waypoint = [origin].
  ///
  /// Returns null if routing fails or service is unavailable.
  Future<ValhallaRoute?> route({
    required LatLng origin,
    required List<LatLng> waypoints,
  }) async {
    if (waypoints.isEmpty) return null;

    // Build Valhalla locations list
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

    try {
      final client = HttpClient();
      client.userAgent = _userAgent;
      final uri = Uri.parse('$_baseUrl/route');
      final request = await client.postUrl(uri).timeout(_timeout);
      request.headers
          .set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('X-Client-Id', _clientId);
      request.write(body);
      final response = await request.close().timeout(_timeout);

      if (response.statusCode == 429 || response.statusCode >= 500) {
        client.close();
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) return null;

      return _parseRoute(responseBody);
    } catch (_) {
      return null;
    }
  }

  ValhallaRoute? _parseRoute(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final trip = json['trip'] as Map<String, dynamic>?;
      if (trip == null) return null;

      final summary = trip['summary'] as Map<String, dynamic>?;
      final lengthKm = (summary?['length'] as num?)?.toDouble() ?? 0.0;
      final durationSec = (summary?['time'] as num?)?.toDouble() ?? 0.0;

      // Decode encoded polyline from legs
      final legs = trip['legs'] as List<dynamic>? ?? [];
      final allPoints = <LatLng>[];

      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final shape = legMap['shape'] as String?;
        if (shape != null) {
          allPoints.addAll(_decodePolyline6(shape));
        }
      }

      if (allPoints.isEmpty) return null;

      return ValhallaRoute(
        points: allPoints,
        distanceMeters: lengthKm * 1000.0,
        durationSeconds: durationSec,
      );
    } catch (_) {
      return null;
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
