import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fitbuddy/features/maps/data/services/map_tile_config.dart';
import 'package:flutter/foundation.dart';

/// Categorized network error classification for diagnostics probes.
enum DiagnosticsErrorType {
  none,
  dnsFailure,
  connectionRefused,
  tlsError,
  timeout,
  badStatus,
  unknown,
}

/// Result of an individual service probe.
@immutable
class ServiceProbeResult {
  const ServiceProbeResult({
    required this.serviceName,
    required this.host,
    required this.isReachable,
    required this.latency,
    this.statusCode,
    required this.errorType,
    required this.details,
  });

  final String serviceName;
  final String host;
  final bool isReachable;
  final Duration latency;
  final int? statusCode;
  final DiagnosticsErrorType errorType;
  final String details;

  String get errorTypeLabel {
    switch (errorType) {
      case DiagnosticsErrorType.none:
        return 'OK';
      case DiagnosticsErrorType.dnsFailure:
        return 'DNS Failure';
      case DiagnosticsErrorType.connectionRefused:
        return 'Connection Refused';
      case DiagnosticsErrorType.tlsError:
        return 'TLS/SSL Error';
      case DiagnosticsErrorType.timeout:
        return 'Timeout';
      case DiagnosticsErrorType.badStatus:
        return 'HTTP $statusCode';
      case DiagnosticsErrorType.unknown:
        return 'Error';
    }
  }

  @override
  String toString() =>
      '$serviceName ($host): ${isReachable ? "REACHABLE" : "UNREACHABLE"} (${latency.inMilliseconds}ms, $errorTypeLabel)';
}

/// Comprehensive diagnostics report for all mapping dependencies.
class MapDiagnosticsReport {
  const MapDiagnosticsReport({
    required this.timestamp,
    required this.results,
    required this.deviceOnline,
  });

  final DateTime timestamp;
  final List<ServiceProbeResult> results;
  final bool deviceOnline;

  /// Generates a sanitized, plain-text report suitable for sharing/clipboard.
  /// Never includes user coordinates or sensitive credentials.
  String toPlainText() {
    final buffer = StringBuffer();
    buffer.writeln('=== Vyayama Map Services Check ===');
    buffer.writeln('Generated: ${timestamp.toUtc().toIso8601String()}');
    buffer.writeln('General Internet: ${deviceOnline ? "CONNECTED" : "OFFLINE"}');
    buffer.writeln('');

    for (final result in results) {
      final statusStr = result.isReachable
          ? 'OK (${result.statusCode ?? 200})'
          : 'FAIL (${result.errorTypeLabel})';
      buffer.writeln(
        '• ${result.serviceName.padRight(28)} : $statusStr - ${result.latency.inMilliseconds}ms [${result.host}]',
      );
      if (!result.isReachable && result.details.isNotEmpty) {
        buffer.writeln('  Reason: ${result.details}');
      }
    }
    buffer.writeln('==================================');
    return buffer.toString();
  }
}

/// Performs non-intrusive diagnostic probes against mapping services and general internet.
///
/// Guaranteed to never transmit or log user GPS coordinates.
class MapDiagnosticsService {
  MapDiagnosticsService({
    HttpClient Function()? clientFactory,
    Future<List<InternetAddress>> Function(String host)? dnsLookup,
  })  : _clientFactory = clientFactory ?? (() => HttpClient()),
        _dnsLookup = dnsLookup ?? ((host) => InternetAddress.lookup(host));

  final HttpClient Function() _clientFactory;
  final Future<List<InternetAddress>> Function(String host) _dnsLookup;

  static const Duration _probeTimeout = Duration(seconds: 5);

  /// Executes all diagnostic probes in parallel and aggregates the results.
  Future<MapDiagnosticsReport> runDiagnostics() async {
    final now = DateTime.now();

    final futures = <Future<ServiceProbeResult>>[
      _probeDns('Neutral DNS (Google)', 'dns.google'),
      _probeGeneralHttps('Neutral HTTPS (Cloudflare)', 'https://cloudflare.com'),
      _probeTiles(),
      ...MapApiConfig.overpassEndpoints.map(_probeOverpassMirror),
      _probeValhalla(),
      _probeNominatim(),
    ];

    final results = await Future.wait(futures);

    // Device is considered online if either neutral DNS or neutral HTTPS succeeded.
    final generalDns = results.firstWhere((r) => r.serviceName.contains('Neutral DNS'));
    final generalHttps = results.firstWhere((r) => r.serviceName.contains('Neutral HTTPS'));
    final isOnline = generalDns.isReachable || generalHttps.isReachable;

    return MapDiagnosticsReport(
      timestamp: now,
      results: results,
      deviceOnline: isOnline,
    );
  }

  Future<ServiceProbeResult> _probeDns(String serviceName, String host) async {
    final sw = Stopwatch()..start();
    try {
      final addresses = await _dnsLookup(host).timeout(_probeTimeout);
      sw.stop();
      if (addresses.isNotEmpty) {
        return ServiceProbeResult(
          serviceName: serviceName,
          host: host,
          isReachable: true,
          latency: sw.elapsed,
          statusCode: null,
          errorType: DiagnosticsErrorType.none,
          details: 'Resolved ${addresses.length} IP(s)',
        );
      }
      return ServiceProbeResult(
        serviceName: serviceName,
        host: host,
        isReachable: false,
        latency: sw.elapsed,
        errorType: DiagnosticsErrorType.dnsFailure,
        details: 'No IP addresses returned for $host',
      );
    } on TimeoutException {
      sw.stop();
      return ServiceProbeResult(
        serviceName: serviceName,
        host: host,
        isReachable: false,
        latency: sw.elapsed,
        errorType: DiagnosticsErrorType.timeout,
        details: 'DNS resolution timed out after ${_probeTimeout.inSeconds}s',
      );
    } catch (e) {
      sw.stop();
      return ServiceProbeResult(
        serviceName: serviceName,
        host: host,
        isReachable: false,
        latency: sw.elapsed,
        errorType: DiagnosticsErrorType.dnsFailure,
        details: 'DNS lookup failed: $e',
      );
    }
  }

  Future<ServiceProbeResult> _probeGeneralHttps(String serviceName, String url) async {
    final uri = Uri.parse(url);
    final sw = Stopwatch()..start();
    HttpClient? client;
    try {
      client = _clientFactory()..userAgent = MapApiConfig.userAgent;
      final req = await client.headUrl(uri).timeout(_probeTimeout);
      final resp = await req.close().timeout(_probeTimeout);
      sw.stop();
      final reachable = resp.statusCode >= 200 && resp.statusCode < 400;
      return ServiceProbeResult(
        serviceName: serviceName,
        host: uri.host,
        isReachable: reachable,
        latency: sw.elapsed,
        statusCode: resp.statusCode,
        errorType: reachable ? DiagnosticsErrorType.none : DiagnosticsErrorType.badStatus,
        details: reachable ? 'Connected successfully' : 'HTTP status ${resp.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return _classifyHttpException(serviceName, uri.host, e, sw.elapsed);
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  Future<ServiceProbeResult> _probeTiles() async {
    const serviceName = 'OSM Map Tiles';
    final tileUrl = MapTileConfig.tileUrl.replaceAll('{z}', '0').replaceAll('{x}', '0').replaceAll('{y}', '0');
    final uri = Uri.parse(tileUrl);
    final sw = Stopwatch()..start();
    HttpClient? client;
    try {
      client = _clientFactory()..userAgent = MapApiConfig.userAgent;
      final req = await client.getUrl(uri).timeout(_probeTimeout);
      final resp = await req.close().timeout(_probeTimeout);
      sw.stop();
      final reachable = resp.statusCode == 200;
      return ServiceProbeResult(
        serviceName: serviceName,
        host: uri.host,
        isReachable: reachable,
        latency: sw.elapsed,
        statusCode: resp.statusCode,
        errorType: reachable ? DiagnosticsErrorType.none : DiagnosticsErrorType.badStatus,
        details: reachable ? 'Tile 0/0/0 rendered' : 'HTTP status ${resp.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return _classifyHttpException(serviceName, uri.host, e, sw.elapsed);
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  Future<ServiceProbeResult> _probeOverpassMirror(String endpoint) async {
    final uri = Uri.parse(endpoint);
    final serviceName = 'Overpass (${uri.host})';
    final sw = Stopwatch()..start();
    HttpClient? client;
    try {
      client = _clientFactory()..userAgent = MapApiConfig.userAgent;
      final req = await client.postUrl(uri).timeout(_probeTimeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/x-www-form-urlencoded');
      // Tiny query: node 1, no coordinates, 5s server timeout
      req.write('data=${Uri.encodeComponent('[out:json][timeout:5];node(1);out;')}') ;
      final resp = await req.close().timeout(_probeTimeout);
      sw.stop();
      final reachable = resp.statusCode == 200;
      return ServiceProbeResult(
        serviceName: serviceName,
        host: uri.host,
        isReachable: reachable,
        latency: sw.elapsed,
        statusCode: resp.statusCode,
        errorType: reachable ? DiagnosticsErrorType.none : DiagnosticsErrorType.badStatus,
        details: reachable ? 'Mirror responsive' : 'HTTP status ${resp.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return _classifyHttpException(serviceName, uri.host, e, sw.elapsed);
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  Future<ServiceProbeResult> _probeValhalla() async {
    const serviceName = 'Valhalla Routing';
    final uri = Uri.parse('${MapApiConfig.valhallaUrl}/route');
    final sw = Stopwatch()..start();
    HttpClient? client;
    try {
      client = _clientFactory()..userAgent = MapApiConfig.userAgent;
      final req = await client.postUrl(uri).timeout(_probeTimeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      // Tiny fixed neutral route (Berlin fixed points, NO user coordinates)
      final body = jsonEncode({
        'locations': [
          {'lat': 52.5200, 'lon': 13.4050},
          {'lat': 52.5201, 'lon': 13.4051},
        ],
        'costing': 'pedestrian',
      });
      req.write(body);
      final resp = await req.close().timeout(_probeTimeout);
      sw.stop();
      final reachable = resp.statusCode == 200;
      return ServiceProbeResult(
        serviceName: serviceName,
        host: uri.host,
        isReachable: reachable,
        latency: sw.elapsed,
        statusCode: resp.statusCode,
        errorType: reachable ? DiagnosticsErrorType.none : DiagnosticsErrorType.badStatus,
        details: reachable ? 'Routing engine active' : 'HTTP status ${resp.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return _classifyHttpException(serviceName, uri.host, e, sw.elapsed);
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  Future<ServiceProbeResult> _probeNominatim() async {
    const serviceName = 'Nominatim Geocoding';
    final uri = Uri.parse('${MapApiConfig.nominatimUrl}/search').replace(queryParameters: {
      'q': 'test',
      'limit': '1',
      'format': 'json',
    });
    final sw = Stopwatch()..start();
    HttpClient? client;
    try {
      client = _clientFactory()..userAgent = MapApiConfig.userAgent;
      final req = await client.getUrl(uri).timeout(_probeTimeout);
      final resp = await req.close().timeout(_probeTimeout);
      sw.stop();
      final reachable = resp.statusCode == 200;
      return ServiceProbeResult(
        serviceName: serviceName,
        host: uri.host,
        isReachable: reachable,
        latency: sw.elapsed,
        statusCode: resp.statusCode,
        errorType: reachable ? DiagnosticsErrorType.none : DiagnosticsErrorType.badStatus,
        details: reachable ? 'Geocoding active' : 'HTTP status ${resp.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return _classifyHttpException(serviceName, uri.host, e, sw.elapsed);
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  ServiceProbeResult _classifyHttpException(
    String serviceName,
    String host,
    Object error,
    Duration elapsed,
  ) {
    if (error is TimeoutException) {
      return ServiceProbeResult(
        serviceName: serviceName,
        host: host,
        isReachable: false,
        latency: elapsed,
        errorType: DiagnosticsErrorType.timeout,
        details: 'Request timed out after ${_probeTimeout.inSeconds}s',
      );
    }

    final errStr = error.toString().toLowerCase();

    if (error is SocketException) {
      if (errStr.contains('failed host lookup') || errStr.contains('nodename nor servname')) {
        return ServiceProbeResult(
          serviceName: serviceName,
          host: host,
          isReachable: false,
          latency: elapsed,
          errorType: DiagnosticsErrorType.dnsFailure,
          details: 'DNS resolution failed for $host',
        );
      }
      if (errStr.contains('connection refused') || errStr.contains('connection reset')) {
        return ServiceProbeResult(
          serviceName: serviceName,
          host: host,
          isReachable: false,
          latency: elapsed,
          errorType: DiagnosticsErrorType.connectionRefused,
          details: 'Connection refused/reset by $host',
        );
      }
    }

    if (error is HandshakeException || errStr.contains('tls') || errStr.contains('certificate')) {
      return ServiceProbeResult(
        serviceName: serviceName,
        host: host,
        isReachable: false,
        latency: elapsed,
        errorType: DiagnosticsErrorType.tlsError,
        details: 'TLS/Certificate handshake failed with $host',
      );
    }

    return ServiceProbeResult(
      serviceName: serviceName,
      host: host,
      isReachable: false,
      latency: elapsed,
      errorType: DiagnosticsErrorType.unknown,
      details: 'Connection failed: $error',
    );
  }
}
