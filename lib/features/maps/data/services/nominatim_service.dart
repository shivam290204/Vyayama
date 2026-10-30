// lib/features/maps/data/services/nominatim_service.dart

import 'dart:convert';
import 'dart:io';
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

/// Performs geographic place search using the public Nominatim API.
///
/// Rate limited to one request per second per the OSM Nominatim usage policy.
/// Caches results in memory per query string.
class NominatimService {
  NominatimService();

  static const String _endpoint = 'https://nominatim.openstreetmap.org/search';
  static const String _userAgent = 'Vyayama/1.0 (com.vyayama.fitbuddy)';
  static const Duration _timeout = Duration(seconds: 10);

  final Map<String, List<NominatimResult>> _cache = {};
  DateTime? _lastRequestTime;

  /// Searches for [query] and returns up to 5 results.
  /// Returns empty list on error or no results.
  /// Returns cached result if same query was searched before.
  Future<List<NominatimResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    if (_cache.containsKey(trimmed)) return _cache[trimmed]!;

    await _throttle();

    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'q': trimmed,
        'format': 'json',
        'limit': '5',
        'addressdetails': '0',
      });

      final client = HttpClient();
      client.userAgent = _userAgent;
      final request = await client.getUrl(uri).timeout(_timeout);
      request.headers.set('Accept-Language', 'en');
      final response = await request.close().timeout(_timeout);

      final body = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) return [];

      final results = _parse(body);
      _cache[trimmed] = results;
      return results;
    } catch (_) {
      return [];
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

  Future<void> _throttle() async {
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      const minInterval = Duration(seconds: 1);
      if (elapsed < minInterval) {
        await Future<void>.delayed(minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}
