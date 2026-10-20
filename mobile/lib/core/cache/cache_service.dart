import 'dart:async';
import 'package:flutter/foundation.dart';

/// Represents a cached item with an expiration timestamp.
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.createdAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}

/// Centralized in-memory caching engine with:
/// 1. Time-To-Live (TTL) expiration
/// 2. Stale-While-Revalidate support (returns stale data immediately, refreshes in background)
/// 3. Request deduplication (coalesces simultaneous fetches into a single Future)
/// 4. Asynchronous timeout protection (prevents unresponsive database queries from freezing the app)
/// 5. Tag / Prefix-based cache invalidation
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, CacheEntry<dynamic>> _cache = {};
  final Map<String, Future<dynamic>> _inFlightFetches = {};

  /// Retrieves a valid cached item if present and not expired.
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired && entry.data is T) {
      return entry.data as T;
    }
    return null;
  }

  /// Retrieves the raw cache entry (even if expired, for stale-while-revalidate).
  T? getStale<T>(String key) {
    final entry = _cache[key];
    if (entry != null && entry.data is T) {
      return entry.data as T;
    }
    return null;
  }

  /// Explicitly stores an item in the cache with a specified TTL.
  void set<T>(String key, T value, {Duration ttl = const Duration(minutes: 5)}) {
    _cache[key] = CacheEntry<T>(
      data: value,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
  }

  /// Returns cached data immediately if available.
  /// If data is missing or expired, executes [fetcher] in a non-blocking manner.
  /// If [staleWhileRevalidate] is true and expired data is present, returns the stale data
  /// immediately while kicking off [fetcher] in the background to update the cache.
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration ttl = const Duration(minutes: 5),
    bool staleWhileRevalidate = true,
    Duration timeout = const Duration(seconds: 4),
    T? fallback,
  }) async {
    final entry = _cache[key];

    // 1. Fresh cache hit -> return immediately (0ms)
    if (entry != null && !entry.isExpired && entry.data is T) {
      return entry.data as T;
    }

    // 2. Stale cache hit with stale-while-revalidate enabled
    if (entry != null && staleWhileRevalidate && entry.data is T) {
      // Trigger background revalidation without blocking caller
      _triggerBackgroundFetch<T>(key, fetcher, ttl, timeout);
      return entry.data as T;
    }

    // 3. Cache miss or strictly expired -> fetch with deduplication and timeout protection
    return _fetchWithDeduplication<T>(key, fetcher, ttl, timeout, fallback: fallback);
  }

  /// Deduplicates identical in-flight requests and executes with timeout protection.
  Future<T> _fetchWithDeduplication<T>(
    String key,
    Future<T> Function() fetcher,
    Duration ttl,
    Duration timeout, {
    T? fallback,
  }) {
    if (_inFlightFetches.containsKey(key)) {
      return _inFlightFetches[key]!.then((res) => res as T);
    }

    final future = () async {
      try {
        final result = await fetcher().timeout(
          timeout,
          onTimeout: () {
            debugPrint('[CacheService] Fetch for "$key" timed out after $timeout. Falling back.');
            if (fallback != null) return fallback;
            final stale = getStale<T>(key);
            if (stale != null) return stale;
            throw TimeoutException('Cache fetch for "$key" timed out');
          },
        );

        set<T>(key, result, ttl: ttl);
        return result;
      } finally {
        _inFlightFetches.remove(key);
      }
    }();

    _inFlightFetches[key] = future;
    return future;
  }

  /// Runs fetcher in the background to refresh the cache without stalling the UI.
  void _triggerBackgroundFetch<T>(
    String key,
    Future<T> Function() fetcher,
    Duration ttl,
    Duration timeout,
  ) {
    if (_inFlightFetches.containsKey(key)) return;

    _fetchWithDeduplication<T>(key, fetcher, ttl, timeout).catchError((err) {
      debugPrint('[CacheService] Background refresh failed for "$key": $err');
      return getStale<T>(key) as T;
    });
  }

  /// Invalidates a specific cache key.
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidates all keys starting with the provided prefix.
  void invalidatePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Completely empties the in-memory cache.
  void clear() {
    _cache.clear();
    _inFlightFetches.clear();
  }
}
