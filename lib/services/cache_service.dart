/// In-memory cache with TTL and stale-while-revalidate support.
class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  final Map<String, _CacheEntry> _cache = {};

  /// Default TTL: 30 seconds
  static const Duration defaultTtl = Duration(seconds: 30);

  /// Get cached data if fresh (within TTL).
  Map<String, dynamic>? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.isExpired) return null;
    return entry.data;
  }

  /// Get cached data even if stale (for stale-while-revalidate pattern).
  Map<String, dynamic>? getStale(String key) {
    return _cache[key]?.data;
  }

  /// Check if we have a stale entry that needs revalidation.
  bool isStale(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    return entry.isExpired;
  }

  /// Store data in cache with optional TTL.
  void set(String key, Map<String, dynamic> data, [Duration? ttl]) {
    _cache[key] = _CacheEntry(
      data: data,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Remove a specific cache entry.
  void remove(String key) {
    _cache.remove(key);
  }

  /// Remove all entries matching a prefix (e.g., invalidate all site data).
  void removeByPrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear all cache.
  void clear() {
    _cache.clear();
  }
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiresAt;

  _CacheEntry({required this.data, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
