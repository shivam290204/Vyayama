// lib/features/maps/data/services/route_cache.dart

/// Simple in-memory cache with TTL for API responses.
/// Keyed by string; values are typed T via separate typed wrappers.
class RouteCache {
  RouteCache._();
  static final RouteCache instance = RouteCache._();

  static const Duration _ttl = Duration(minutes: 10);

  final Map<String, _CacheEntry<dynamic>> _store = {};

  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > _ttl) {
      _store.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  void set<T>(String key, T value) {
    _store[key] = _CacheEntry<T>(value: value, storedAt: DateTime.now());
  }

  void invalidate(String key) => _store.remove(key);

  void clear() => _store.clear();
}

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.storedAt});
  final T value;
  final DateTime storedAt;
}
