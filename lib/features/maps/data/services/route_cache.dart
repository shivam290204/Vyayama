import 'dart:collection';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:latlong2/latlong.dart';

/// In-memory LRU cache with TTL expiration and structured geographic key isolation.
///
/// Designed to prevent memory bloat and cross-area route collisions while
/// respecting OpenStreetMap and Valhalla caching recommendations.
class RouteCache {
  RouteCache({
    this.maxEntries = 100,
    this.ttl = const Duration(minutes: 10),
  });

  /// Default application-wide singleton instance.
  static final RouteCache instance = RouteCache();

  /// Maximum number of items retained in memory before LRU eviction.
  final int maxEntries;

  /// Default time-to-live for cached items.
  final Duration ttl;

  final LinkedHashMap<String, _CacheEntry<dynamic>> _store =
      LinkedHashMap<String, _CacheEntry<dynamic>>();

  /// Current number of non-expired entries in cache.
  int get size => _store.length;

  /// Retrieves a cached value of type [T] by [key].
  ///
  /// Promotes the item to most recently used.
  /// Evicts and returns null if expired.
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;

    final now = DateTime.now();
    if (now.difference(entry.storedAt) > entry.effectiveTtl) {
      _store.remove(key);
      return null;
    }

    // Refresh LRU order: remove and re-insert at tail
    _store.remove(key);
    _store[key] = entry;
    return entry.value as T?;
  }

  /// Stores [value] under [key] with optional [customTtl].
  ///
  /// Evicts the least recently used entry if [maxEntries] is reached.
  void set<T>(String key, T value, {Duration? customTtl}) {
    if (_store.containsKey(key)) {
      _store.remove(key);
    } else if (_store.length >= maxEntries && _store.isNotEmpty) {
      // Evict oldest (least recently used) entry
      final oldestKey = _store.keys.first;
      _store.remove(oldestKey);
    }

    _store[key] = _CacheEntry<T>(
      value: value,
      storedAt: DateTime.now(),
      effectiveTtl: customTtl ?? ttl,
    );
  }

  /// Checks if [key] exists in cache and is not expired without updating LRU order.
  bool contains(String key) {
    final entry = _store[key];
    if (entry == null) return false;
    if (DateTime.now().difference(entry.storedAt) > entry.effectiveTtl) {
      _store.remove(key);
      return false;
    }
    return true;
  }

  /// Invalidates a specific cache entry.
  void invalidate(String key) => _store.remove(key);

  /// Clears all entries from the cache.
  void clear() => _store.clear();

  // ---------------------------------------------------------------------------
  // Geographic Key Generators
  // ---------------------------------------------------------------------------

  /// Builds a normalized geographic search area cache key.
  ///
  /// Coordinates are rounded to 3 decimal places (~110 m precision) to allow
  /// cache hits for small camera adjustments while avoiding cross-area collisions.
  static String buildAreaKey({
    required LatLng center,
    required double radiusMeters,
    OutdoorActivityType? activityType,
    RouteFilter? filter,
    String prefix = 'routes',
  }) {
    final lat = center.latitude.toStringAsFixed(3);
    final lon = center.longitude.toStringAsFixed(3);
    final r = radiusMeters.round();
    final act = activityType?.name ?? 'all';
    final filterKey = filter != null
        ? '${filter.minDistanceKm ?? 0}_${filter.maxDistanceKm ?? 0}_'
          '${filter.difficulty?.name ?? "any"}_${filter.surface?.name ?? "any"}'
        : 'default';

    return '$prefix:$lat,$lon:r=$r:act=$act:f=$filterKey';
  }

  /// Builds an Overpass places cache key.
  static String buildOverpassKey(LatLng center, double radiusMeters) {
    return 'overpass:${center.latitude.toStringAsFixed(3)},'
        '${center.longitude.toStringAsFixed(3)}:r=${radiusMeters.round()}';
  }

  /// Builds a Valhalla routing cache key.
  static String buildValhallaKey(LatLng origin, List<LatLng> waypoints) {
    final wpStr = waypoints
        .map((w) => '${w.latitude.toStringAsFixed(4)},${w.longitude.toStringAsFixed(4)}')
        .join('->');
    return 'valhalla:${origin.latitude.toStringAsFixed(4)},${origin.longitude.toStringAsFixed(4)}:$wpStr';
  }

  /// Builds a Nominatim nearby places cache key.
  static String buildNominatimNearbyKey(LatLng center, double radiusMeters) {
    return 'nominatim_nearby:${center.latitude.toStringAsFixed(3)},'
        '${center.longitude.toStringAsFixed(3)}:r=${radiusMeters.round()}';
  }

  /// Builds a Nominatim query search cache key.
  static String buildNominatimSearchKey(String query) {
    return 'nominatim_search:${query.trim().toLowerCase()}';
  }
}

class _CacheEntry<T> {
  const _CacheEntry({
    required this.value,
    required this.storedAt,
    required this.effectiveTtl,
  });

  final T value;
  final DateTime storedAt;
  final Duration effectiveTtl;
}
