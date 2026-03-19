import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Persistent cache with TTL and stale-while-revalidate support.
/// Uses Hive for persistence, falling back to in-memory if Hive is unavailable.
class CacheService {
  static final CacheService _instance = CacheService._();
  factory CacheService() => _instance;
  CacheService._();

  static const String _boxName = 'api_cache';
  Box? _box;
  // In-memory fallback used when Hive is not yet initialized
  final Map<String, _CacheEntry> _memCache = {};

  /// Default TTL: 30 seconds
  static const Duration defaultTtl = Duration(seconds: 30);

  /// Initialize the Hive box. Call after Hive.initFlutter().
  Future<void> init() async {
    try {
      _box = await Hive.openBox(_boxName);
    } catch (e) {
      debugPrint('CacheService: Hive init failed, using memory cache: $e');
    }
  }

  /// Get cached data if fresh (within TTL).
  Map<String, dynamic>? get(String key) {
    final entry = _getEntry(key);
    if (entry == null) return null;
    if (entry.isExpired) return null;
    return entry.data;
  }

  /// Get cached data even if stale (for stale-while-revalidate pattern).
  Map<String, dynamic>? getStale(String key) {
    return _getEntry(key)?.data;
  }

  /// Check if we have a stale entry that needs revalidation.
  bool isStale(String key) {
    final entry = _getEntry(key);
    if (entry == null) return false;
    return entry.isExpired;
  }

  /// Store data in cache with optional TTL.
  void set(String key, Map<String, dynamic> data, [Duration? ttl]) {
    final entry = _CacheEntry(
      data: data,
      expiresAt: DateTime.now().add(ttl ?? defaultTtl),
    );

    if (_box != null) {
      _box!.put(key, entry.toJson());
    } else {
      _memCache[key] = entry;
    }
  }

  /// Remove a specific cache entry.
  void remove(String key) {
    if (_box != null) {
      _box!.delete(key);
    } else {
      _memCache.remove(key);
    }
  }

  /// Remove all entries matching a prefix (e.g., invalidate all site data).
  void removeByPrefix(String prefix) {
    if (_box != null) {
      final keysToRemove =
          _box!.keys.where((k) => k.toString().startsWith(prefix)).toList();
      _box!.deleteAll(keysToRemove);
    } else {
      _memCache.removeWhere((key, _) => key.startsWith(prefix));
    }
  }

  /// Clear all cache.
  void clear() {
    if (_box != null) {
      _box!.clear();
    } else {
      _memCache.clear();
    }
  }

  _CacheEntry? _getEntry(String key) {
    if (_box != null) {
      final raw = _box!.get(key);
      if (raw == null) return null;
      try {
        return _CacheEntry.fromJson(raw);
      } catch (_) {
        _box!.delete(key);
        return null;
      }
    } else {
      return _memCache[key];
    }
  }
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiresAt;

  _CacheEntry({required this.data, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String toJson() {
    return jsonEncode({
      'data': data,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    });
  }

  factory _CacheEntry.fromJson(dynamic raw) {
    final map = raw is String ? jsonDecode(raw) : raw as Map;
    return _CacheEntry(
      data: Map<String, dynamic>.from(map['data']),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt']),
    );
  }
}
