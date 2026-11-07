import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:fitbuddy/features/maps/data/services/circuit_breaker.dart';
import 'package:fitbuddy/features/maps/data/services/map_api_config.dart';
import 'package:fitbuddy/features/maps/data/services/route_cache.dart';
import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';
import 'package:fitbuddy/features/maps/domain/services/connectivity_monitor.dart';
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

  /// Whether this feature is publicly accessible for walking/hiking.
  bool get isAccessible {
    final access = tags['access']?.toLowerCase();
    final foot = tags['foot']?.toLowerCase();
    return access != 'no' && access != 'private' && foot != 'no';
  }

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
/// Implements LRU caching and request throttling to avoid excessive server requests.
class OverpassService {
  OverpassService({
    RouteCache? cache,
    String? endpoint,
    List<String>? endpoints,
    HttpClient Function()? clientFactory,
    this.retryBackoff = const Duration(milliseconds: 1500),
    ConnectivityMonitor? connectivityMonitor,
    Future<bool> Function()? isOfflineProbe,
    ServiceCircuitBreaker? circuitBreaker,
  })  : _cache = cache ?? RouteCache.instance,
        _endpoints = endpoints ??
            (endpoint != null
                ? [endpoint]
                : MapApiConfig.overpassEndpoints),
        _clientFactory = clientFactory ?? (() => HttpClient()),
        _connectivityMonitor = connectivityMonitor,
        _isOfflineProbe = isOfflineProbe,
        _circuitBreaker = circuitBreaker ??
            ServiceCircuitBreaker(
              serviceName: 'OpenStreetMap Places',
              failureThreshold: 3,
              cooldownDuration: const Duration(seconds: 60),
            );

  static List<String> get defaultEndpoints => MapApiConfig.overpassEndpoints;

  final List<String> _endpoints;
  final HttpClient Function() _clientFactory;
  final Duration retryBackoff;
  final ConnectivityMonitor? _connectivityMonitor;
  final Future<bool> Function()? _isOfflineProbe;
  final ServiceCircuitBreaker _circuitBreaker;
  /// Per-request HTTP client timeout (connect + response).
  /// Shorter than the server-side `[timeout:N]` to avoid hanging.
  static const Duration _timeout = Duration(seconds: 5);

  /// Maximum number of places returned per Overpass query.
  static const int _maxResults = 30;

  /// Starting search radius when the caller does not specify one.
  static const double _initialRadiusMeters = 2000;

  /// Expanded radius used when the first pass returns too few results.
  static const double _expandedRadiusMeters = 5000;

  /// Overall budget for a single findNearbyPlaces call (all mirrors + retries).
  static const Duration _overallBudget = Duration(seconds: 12);

  final RouteCache _cache;
  DateTime? _lastRequestTime;
  DateTime? _rateLimitedUntil;
  final Map<String, DateTime> _endpointCooldowns = {};
  final List<OverpassMirrorAttempt> _lastMirrorAttempts = [];

  /// Historical log of mirror attempts from the most recent query.
  List<OverpassMirrorAttempt> get lastMirrorAttempts =>
      List.unmodifiable(_lastMirrorAttempts);

  /// Resets rate limit and endpoint cooldowns for unit tests.
  void resetRateLimitForTesting() {
    _rateLimitedUntil = null;
    _endpointCooldowns.clear();
    _lastMirrorAttempts.clear();
    _circuitBreaker.reset();
  }

  void _recordEndpointCooldown(String endpoint, Duration duration) {
    _endpointCooldowns[endpoint] = DateTime.now().add(duration);
  }

  bool _isEndpointInCooldown(String endpoint) {
    final cooldownUntil = _endpointCooldowns[endpoint];
    if (cooldownUntil == null) return false;
    if (DateTime.now().isBefore(cooldownUntil)) {
      return true;
    }
    _endpointCooldowns.remove(endpoint);
    return false;
  }

  static Duration? _parseRetryAfterDuration(String? headerValue) {
    if (headerValue == null || headerValue.trim().isEmpty) return null;
    final trimmed = headerValue.trim();
    final seconds = int.tryParse(trimmed);
    if (seconds != null && seconds >= 0) {
      return Duration(seconds: seconds);
    }
    try {
      final date = HttpDate.parse(trimmed);
      final diff = date.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return null;
    }
  }

  Future<NetworkReachabilityStatus> _determineReachability() async {
    if (_connectivityMonitor != null) {
      return await _connectivityMonitor.checkReachability();
    }
    if (_isOfflineProbe != null) {
      try {
        final isOffline = await _isOfflineProbe();
        return isOffline
            ? NetworkReachabilityStatus.offline
            : NetworkReachabilityStatus.online;
      } catch (_) {
        // Requirement 5: Do not classify a failed connectivity probe as definitely offline.
        // Handle unknown connectivity separately.
        return NetworkReachabilityStatus.unknown;
      }
    }
    return NetworkReachabilityStatus.unknown;
  }

  /// Active client tracking for safe cancellation.
  final Set<HttpClient> _activeClients = {};
  final Map<int, Set<HttpClient>> _generationClients = {};
  final Set<int> _cancelledRequestIds = {};
  bool _allCancelled = false;

  /// Cancels in-flight network requests.
  /// If [requestId] is provided, cancels only clients for that generation.
  void cancelActiveRequests([int? requestId]) {
    if (requestId != null) {
      _cancelledRequestIds.add(requestId);
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
      _allCancelled = true;
      for (final client in _activeClients) {
        try {
          client.close(force: true);
        } catch (_) {}
      }
      _activeClients.clear();
      _generationClients.clear();
    }
  }

  bool _isCancelled(int? requestId) {
    if (_allCancelled) return true;
    if (requestId != null && _cancelledRequestIds.contains(requestId)) return true;
    return false;
  }

  /// Finds parks, recreation grounds, trails, footways, and hiking routes within [radiusMeters]
  /// of [center].
  ///
  /// Throws [RouteRateLimitException] on HTTP 429.
  /// Throws [OverpassServiceException] on server error (HTTP 5xx).
  /// Throws [RouteNetworkException] on connection failure or timeout.
  Future<List<OverpassPlace>> findNearbyPlaces({
    required LatLng center,
    required double radiusMeters,
    int? requestId,
  }) async {
    _circuitBreaker.protect();

    if (_rateLimitedUntil != null &&
        DateTime.now().isBefore(_rateLimitedUntil!)) {
      throw const RouteRateLimitException(
          'OpenStreetMap rate limit reached. Please wait a moment.');
    }

    // Validate coordinates
    if (!center.latitude.isFinite ||
        !center.longitude.isFinite ||
        center.latitude < -90 ||
        center.latitude > 90 ||
        center.longitude < -180 ||
        center.longitude > 180) {
      return [];
    }

    final cacheKey = RouteCache.buildOverpassKey(center, radiusMeters);

    final cached = _cache.get<List<OverpassPlace>>(cacheKey);
    if (cached != null) return cached;

    // Fast-path: if device is confirmed offline, fail immediately without wasting time on network timeouts
    final initialReachability = await _determineReachability();
    if (initialReachability == NetworkReachabilityStatus.offline) {
      throw const DeviceOfflineException(
          'No internet connection. Please check your network and try again.');
    }

    if (_endpoints.isNotEmpty && _endpoints.every(_isEndpointInCooldown)) {
      throw const OverpassServiceException(
          'Nearby places temporarily unavailable.');
    }

    await _throttle();

    final lat = center.latitude;
    final lon = center.longitude;

    // -------------------------------------------------------------------------
    // Phase 2(a): Progressive radius — start small (~2.5 km), expand only if
    // the first pass returns no results.
    // -------------------------------------------------------------------------
    final deadline = DateTime.now().add(_overallBudget);

    final initialR = math.min(radiusMeters, _initialRadiusMeters).round();
    List<OverpassPlace> results = await _queryWithRadius(
      lat: lat,
      lon: lon,
      radiusMeters: initialR,
      requestId: requestId,
      deadline: deadline,
    );

    // Expand only if there are too few (or zero) results and radiusMeters was larger
    if (results.isEmpty &&
        radiusMeters > _initialRadiusMeters &&
        DateTime.now().isBefore(deadline)) {
      final expandedR = radiusMeters.clamp(300, _expandedRadiusMeters).round();
      final expanded = await _queryWithRadius(
        lat: lat,
        lon: lon,
        radiusMeters: expandedR,
        requestId: requestId,
        deadline: deadline,
      );
      if (expanded.isNotEmpty) {
        results = expanded;
      }
    }

    if (!_isCancelled(requestId)) {
      _cache.set(cacheKey, results);
    }
    _circuitBreaker.recordSuccess();
    return results;
  }

  // ---------------------------------------------------------------------------
  // Split query strategy (Phase 2a):
  //   Pass 1 — named leisure areas only (small, fast, index-friendly).
  //   Pass 2 — footways/paths/tracks (can be large; use smaller sub-radius).
  // ---------------------------------------------------------------------------

  /// Builds the named-parks Overpass QL for a given radius.
  String _parksQuery(int r, double lat, double lon) => '''
[out:json][timeout:20];
(
  node["leisure"="park"]["name"](around:$r,$lat,$lon);
  way["leisure"="park"]["name"](around:$r,$lat,$lon);
  node["leisure"="recreation_ground"]["name"](around:$r,$lat,$lon);
  way["leisure"="recreation_ground"]["name"](around:$r,$lat,$lon);
  way["leisure"="nature_reserve"]["name"](around:$r,$lat,$lon);
  way["leisure"="garden"]["name"](around:$r,$lat,$lon);
);
out center $_maxResults;
''';

  /// Builds the footways/paths query for a given (smaller) radius.
  String _pathsQuery(int r, double lat, double lon) => '''
[out:json][timeout:20];
(
  way["highway"="footway"](around:$r,$lat,$lon);
  way["highway"="pedestrian"](around:$r,$lat,$lon);
  way["highway"="path"](around:$r,$lat,$lon);
  way["highway"="track"](around:$r,$lat,$lon);
  relation["route"="hiking"](around:$r,$lat,$lon);
  relation["route"="foot"](around:$r,$lat,$lon);
);
out center $_maxResults;
''';

  /// Runs progressive queries for [radiusMeters].
  /// Queries named parks first (lightweight, index-friendly). If found, returns them immediately.
  /// Only falls back to paths/tracks if no named parks were found.
  Future<List<OverpassPlace>> _queryWithRadius({
    required double lat,
    required double lon,
    required int radiusMeters,
    required int? requestId,
    required DateTime deadline,
  }) async {
    // Named parks first — fast and index-friendly.
    final parks = await _executeQuery(
      query: _parksQuery(radiusMeters, lat, lon),
      requestId: requestId,
      deadline: deadline,
    );

    if (parks.isNotEmpty ||
        _isCancelled(requestId) ||
        DateTime.now().isAfter(deadline)) {
      return parks;
    }

    // Paths in a tighter sub-radius to keep response size manageable.
    final pathRadius = (radiusMeters * 0.6).round().clamp(300, radiusMeters);
    try {
      final paths = await _executeQuery(
        query: _pathsQuery(pathRadius, lat, lon),
        requestId: requestId,
        deadline: deadline,
      );
      return paths;
    } catch (_) {
      // Return whatever we have (even if empty)
      return parks;
    }
  }

  /// Executes a single Overpass QL [query] against all configured mirrors,
  /// respecting the overall [deadline] budget.
  Future<List<OverpassPlace>> _executeQuery({
    required String query,
    required int? requestId,
    required DateTime deadline,
  }) async {
    RouteDiscoveryException? lastException;
    final failedEndpointsThisCall = <String>{};
    _lastMirrorAttempts.clear();

    for (int attempt = 0; attempt <= 1; attempt++) {
      if (_isCancelled(requestId)) {
        throw const RouteNetworkException('Request was cancelled.');
      }

      // Stop if we've exceeded the overall budget
      if (DateTime.now().isAfter(deadline)) {
        break;
      }

      // Exponential backoff before retry attempt
      if (attempt > 0) {
        final backoffDelay = retryBackoff * math.pow(2, attempt - 1);
        await Future<void>.delayed(backoffDelay);
        if (_isCancelled(requestId)) {
          throw const RouteNetworkException('Request was cancelled.');
        }
        if (DateTime.now().isAfter(deadline)) break;
      }

      for (final ep in _endpoints) {
        if (_isCancelled(requestId)) {
          throw const RouteNetworkException('Request was cancelled.');
        }

        // Stop if we've exceeded the overall budget
        if (DateTime.now().isAfter(deadline)) break;

        // Skip endpoints in active cooldown from earlier failures or explicit Retry-After
        if (_isEndpointInCooldown(ep)) {
          continue;
        }

        HttpClient? client;
        final sw = Stopwatch()..start();
        final uri = Uri.parse(ep);

        try {
          client = _clientFactory()..userAgent = MapApiConfig.userAgent;
          _activeClients.add(client);
          if (requestId != null) {
            _generationClients.putIfAbsent(requestId, () => {}).add(client);
          }

          final request = await client.postUrl(uri).timeout(_timeout);
          request.headers.set(
              HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
          request.write('data=${Uri.encodeComponent(query)}');
          final response = await request.close().timeout(_timeout);
          sw.stop();

          if (response.statusCode == 429) {
            final retryAfter = response.headers.value(HttpHeaders.retryAfterHeader);
            final duration = _parseRetryAfterDuration(retryAfter) ?? const Duration(seconds: 30);
            _rateLimitedUntil = DateTime.now().add(duration);
            _lastMirrorAttempts.add(OverpassMirrorAttempt(
              endpoint: ep,
              timestamp: DateTime.now(),
              duration: sw.elapsed,
              statusCode: 429,
              errorType: 'rate_limit',
              errorMessage: 'OpenStreetMap request limit reached.',
            ));
            throw RouteRateLimitException(
              'OpenStreetMap request limit reached. Please wait a moment.',
              'OpenStreetMap',
              uri.host,
              duration,
            );
          }

          if (response.statusCode >= 500) {
            failedEndpointsThisCall.add(ep);
            final retryAfter = response.headers.value(HttpHeaders.retryAfterHeader);
            if (retryAfter != null) {
              final duration = _parseRetryAfterDuration(retryAfter) ?? const Duration(seconds: 60);
              _recordEndpointCooldown(ep, duration);
            }
            _lastMirrorAttempts.add(OverpassMirrorAttempt(
              endpoint: ep,
              timestamp: DateTime.now(),
              duration: sw.elapsed,
              statusCode: response.statusCode,
              errorType: 'bad_status',
              errorMessage: 'Server error HTTP ${response.statusCode}',
            ));
            lastException = OverpassServiceException(
              'OpenStreetMap service returned server error (${response.statusCode}).',
              response.statusCode,
              uri.host,
            );
            continue;
          }

          if (response.statusCode != 200) {
            failedEndpointsThisCall.add(ep);
            _lastMirrorAttempts.add(OverpassMirrorAttempt(
              endpoint: ep,
              timestamp: DateTime.now(),
              duration: sw.elapsed,
              statusCode: response.statusCode,
              errorType: 'bad_status',
              errorMessage: 'Unexpected status HTTP ${response.statusCode}',
            ));
            lastException = BadResponseException(
              serviceName: 'OpenStreetMap',
              host: uri.host,
              statusCode: response.statusCode,
            );
            continue;
          }

          final body = await response.transform(utf8.decoder).join().timeout(_timeout);
          final places = parseOverpassResponse(body);

          _lastMirrorAttempts.add(OverpassMirrorAttempt(
            endpoint: ep,
            timestamp: DateTime.now(),
            duration: sw.elapsed,
            statusCode: 200,
            succeeded: true,
          ));

          // Mark any mirrors that failed before this successful one into cooldown
          failedEndpointsThisCall.remove(ep);
          for (final failedEp in failedEndpointsThisCall) {
            _recordEndpointCooldown(failedEp, const Duration(seconds: 60));
          }

          return places;
        } on SocketException catch (e) {
          sw.stop();
          failedEndpointsThisCall.add(ep);
          final reachability = await _determineReachability();
          if (reachability == NetworkReachabilityStatus.offline) {
            _lastMirrorAttempts.add(OverpassMirrorAttempt(
              endpoint: ep,
              timestamp: DateTime.now(),
              duration: sw.elapsed,
              errorType: 'dns_failure',
              errorMessage: 'Device offline',
            ));
            throw const DeviceOfflineException(
                'No internet connection. Please check your network and try again.');
          } else {
            _lastMirrorAttempts.add(OverpassMirrorAttempt(
              endpoint: ep,
              timestamp: DateTime.now(),
              duration: sw.elapsed,
              errorType: 'connection_refused',
              errorMessage: e.message,
            ));
            lastException = ServiceUnreachableException(
              serviceName: 'OpenStreetMap',
              host: uri.host,
              cause: e,
            );
          }
        } on TimeoutException catch (_) {
          sw.stop();
          failedEndpointsThisCall.add(ep);
          _lastMirrorAttempts.add(OverpassMirrorAttempt(
            endpoint: ep,
            timestamp: DateTime.now(),
            duration: sw.elapsed,
            errorType: 'timeout',
            errorMessage: 'Timed out waiting for response',
          ));
          lastException = ServiceTimeoutException(
            serviceName: 'OpenStreetMap',
            host: uri.host,
            duration: _timeout,
          );
        } on ServiceRateLimitedException {
          // HTTP 429 stops mirror rotation immediately without querying subsequent mirrors
          // and must NEVER be retried.
          rethrow;
        } on RouteDiscoveryException catch (e) {
          sw.stop();
          failedEndpointsThisCall.add(ep);
          _lastMirrorAttempts.add(OverpassMirrorAttempt(
            endpoint: ep,
            timestamp: DateTime.now(),
            duration: sw.elapsed,
            errorType: 'unknown',
            errorMessage: e.message,
          ));
          lastException = e;
        } catch (e) {
          sw.stop();
          failedEndpointsThisCall.add(ep);
          _lastMirrorAttempts.add(OverpassMirrorAttempt(
            endpoint: ep,
            timestamp: DateTime.now(),
            duration: sw.elapsed,
            errorType: 'unknown',
            errorMessage: '$e',
          ));
          lastException =
              OverpassServiceException('Failed to process OpenStreetMap data: $e');
        } finally {
          if (client != null) {
            _activeClients.remove(client);
            if (requestId != null) {
              _generationClients[requestId]?.remove(client);
            }
            try {
              client.close(force: true);
            } catch (_) {}
          }
        }
      }
    }

    // All endpoints exhausted across attempts: record cooldown on failed endpoints
    for (final failedEp in failedEndpointsThisCall) {
      _recordEndpointCooldown(failedEp, const Duration(seconds: 60));
    }

    _circuitBreaker.recordFailure();

    if (_lastMirrorAttempts.isNotEmpty && _lastMirrorAttempts.every((a) => a.errorType == 'timeout')) {
      throw const ServiceTimeoutException(
        serviceName: 'OpenStreetMap',
        duration: _timeout,
      );
    }

    if (_lastMirrorAttempts.isNotEmpty) {
      throw AllOverpassMirrorsFailedException(
        attempts: List.unmodifiable(_lastMirrorAttempts),
      );
    }

    if (lastException != null) {
      throw lastException;
    }
    throw const OverpassServiceException();
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
        if (!lat.isFinite || !lon.isFinite) continue;
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        final place = OverpassPlace(
          id: (map['id'] as num).toInt(),
          name: name,
          lat: lat,
          lon: lon,
          tags: tags,
          isNamed: isNamed,
        );

        // Filter out non-accessible ways (e.g. access=no, access=private, foot=no)
        if (!place.isAccessible) continue;

        results.add(place);
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
      const minInterval = Duration(milliseconds: 1500);
      if (elapsed < minInterval) {
        await Future<void>.delayed(minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }
}
