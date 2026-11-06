import 'package:flutter/foundation.dart';

/// Base exception hierarchy for Maps and Outdoor Route Discovery.
@immutable
sealed class RouteDiscoveryException implements Exception {
  const RouteDiscoveryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Base network exception class for backward compatibility and network errors.
class RouteNetworkException extends RouteDiscoveryException {
  const RouteNetworkException([
    super.message = 'No internet connection. Please check your network and try again.',
  ]);
}

/// Thrown when device has confirmed no general internet connectivity
/// (e.g. airplane mode, disconnected interface, or general neutral probe fails).
class DeviceOfflineException extends RouteNetworkException {
  const DeviceOfflineException([
    super.message = 'No internet connection. Please check your network and try again.',
  ]);
}

/// Thrown when a specific service host is unreachable
/// (host-specific DNS lookup failure, connection refused, socket reset, or TLS error).
class ServiceUnreachableException extends RouteNetworkException {
  const ServiceUnreachableException({
    required this.serviceName,
    required this.host,
    this.cause,
    String? message,
  }) : super(message ?? '$serviceName ($host) is unreachable.');

  final String serviceName;
  final String host;
  final Object? cause;
}

/// Thrown when a request to an external service times out.
class ServiceTimeoutException extends RouteNetworkException {
  const ServiceTimeoutException({
    required this.serviceName,
    this.host,
    this.duration,
    String? message,
  }) : super(message ?? '$serviceName timed out waiting for a response.');

  final String serviceName;
  final String? host;
  final Duration? duration;
}

/// Thrown when OpenStreetMap Overpass API, Valhalla, or Nominatim returns HTTP 429.
class ServiceRateLimitedException extends RouteDiscoveryException {
  const ServiceRateLimitedException({
    String? message,
    this.serviceName = 'OpenStreetMap',
    this.host,
    this.retryAfter,
  }) : super(
          message ??
              'OpenStreetMap request limit reached. Please wait a moment and try again.',
        );

  final String serviceName;
  final String? host;
  final Duration? retryAfter;
}

/// Backward compatibility subclass for callers/tests expecting RouteRateLimitException.
class RouteRateLimitException extends ServiceRateLimitedException {
  const RouteRateLimitException([
    String? message,
    String serviceName = 'OpenStreetMap',
    String? host,
    Duration? retryAfter,
  ]) : super(
          message: message,
          serviceName: serviceName,
          host: host,
          retryAfter: retryAfter,
        );
}

/// Thrown when a service returns HTTP 5xx server error.
class ServiceErrorException extends RouteDiscoveryException {
  const ServiceErrorException({
    required this.serviceName,
    this.host,
    this.statusCode,
    String? message,
  }) : super(
          message ??
              '$serviceName data server is currently busy or experiencing an outage. Tap below to retry.',
        );

  final String serviceName;
  final String? host;
  final int? statusCode;
}

/// Backward compatibility subclass for tests expecting OverpassServiceException.
class OverpassServiceException extends ServiceErrorException {
  const OverpassServiceException([
    String message = 'Nearby places temporarily unavailable.',
    int? statusCode,
    String? host,
  ]) : super(
          serviceName: 'OpenStreetMap',
          host: host,
          statusCode: statusCode,
          message: message,
        );
}

/// Backward compatibility subclass for tests expecting ValhallaRoutingException.
class ValhallaRoutingException extends ServiceErrorException {
  const ValhallaRoutingException([
    String message = 'Pedestrian routing service is temporarily unavailable. Tap below to retry.',
    int? statusCode,
    String? host,
  ]) : super(
          serviceName: 'Pedestrian Routing',
          host: host,
          statusCode: statusCode,
          message: message,
        );
}

/// Thrown when a service returns an unexpected HTTP response (e.g. 400, 403, 404) or malformed body.
class BadResponseException extends RouteDiscoveryException {
  const BadResponseException({
    required this.serviceName,
    this.host,
    this.statusCode,
    String? message,
  }) : super(
          message ??
              '$serviceName returned an unexpected response${statusCode != null ? ' ($statusCode)' : ''}. Tap below to retry.',
        );

  final String serviceName;
  final String? host;
  final int? statusCode;
}

/// Individual mirror attempt record captured during multi-mirror queries.
class OverpassMirrorAttempt {
  const OverpassMirrorAttempt({
    required this.endpoint,
    required this.timestamp,
    required this.duration,
    this.statusCode,
    this.errorType,
    this.errorMessage,
    this.succeeded = false,
  });

  final String endpoint;
  final DateTime timestamp;
  final Duration duration;
  final int? statusCode;
  final String? errorType;
  final String? errorMessage;
  final bool succeeded;

  @override
  String toString() =>
      'OverpassMirrorAttempt($endpoint, status: $statusCode, error: $errorType, dur: ${duration.inMilliseconds}ms)';
}

/// Composite exception aggregating all mirror attempts when all fail.
class AllOverpassMirrorsFailedException extends OverpassServiceException {
  const AllOverpassMirrorsFailedException({
    required this.attempts,
    String? message,
  }) : super(
          message ?? 'Nearby places temporarily unavailable.',
        );

  final List<OverpassMirrorAttempt> attempts;
}

/// Thrown when a service circuit breaker is open after consecutive failures.
class CircuitBreakerOpenException extends RouteDiscoveryException {
  CircuitBreakerOpenException({
    required this.serviceName,
    required this.cooldownRemaining,
    String? message,
  }) : super(
          message ??
              '$serviceName is temporarily paused after consecutive failures. Retrying in ${cooldownRemaining.inSeconds}s.',
        );

  final String serviceName;
  final Duration cooldownRemaining;
}
