/// Exception hierarchy for Maps and Outdoor Route Discovery.
sealed class RouteDiscoveryException implements Exception {
  const RouteDiscoveryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when device has no internet connectivity or connection times out.
class RouteNetworkException extends RouteDiscoveryException {
  const RouteNetworkException([
    super.message = 'No internet connection. Please check your network and try again.',
  ]);
}

/// Thrown when OpenStreetMap Overpass API or Valhalla returns HTTP 429.
class RouteRateLimitException extends RouteDiscoveryException {
  const RouteRateLimitException([
    super.message = 'Route discovery rate limit reached. Please wait a few seconds and try again.',
  ]);
}

/// Thrown when OpenStreetMap Overpass API returns 5xx or fails.
class OverpassServiceException extends RouteDiscoveryException {
  const OverpassServiceException([
    super.message = 'OpenStreetMap data service is temporarily unavailable. Please try again shortly.',
  ]);
}

/// Thrown when Valhalla pedestrian routing engine returns 5xx or fails.
class ValhallaRoutingException extends RouteDiscoveryException {
  const ValhallaRoutingException([
    super.message = 'Pedestrian routing service is temporarily unavailable. Please try again shortly.',
  ]);
}

