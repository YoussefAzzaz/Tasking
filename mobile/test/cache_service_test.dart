import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/user_profile_repository.dart';

void main() {
  setUp(() {
    CacheService().clear();
  });

  group('CacheService Tests', () {
    test('Stores and retrieves valid cache entry', () {
      final cache = CacheService();
      cache.set('test_key', 'hello_world', ttl: const Duration(seconds: 10));

      expect(cache.get<String>('test_key'), equals('hello_world'));
    });

    test('Returns null for missing or expired entry', () async {
      final cache = CacheService();
      expect(cache.get<String>('non_existent'), isNull);

      cache.set('short_lived', 123, ttl: const Duration(milliseconds: 10));
      await Future.delayed(const Duration(milliseconds: 25));

      expect(cache.get<int>('short_lived'), isNull);
      expect(cache.getStale<int>('short_lived'), equals(123));
    });

    test('getOrFetch returns cached value without executing fetcher', () async {
      final cache = CacheService();
      cache.set('key', 42);

      int fetchCount = 0;
      final result = await cache.getOrFetch('key', () async {
        fetchCount++;
        return 100;
      });

      expect(result, equals(42));
      expect(fetchCount, equals(0));
    });

    test('getOrFetch executes fetcher and caches result on cache miss', () async {
      final cache = CacheService();
      int fetchCount = 0;

      final result = await cache.getOrFetch('key_miss', () async {
        fetchCount++;
        return 'fetched_data';
      });

      expect(result, equals('fetched_data'));
      expect(fetchCount, equals(1));
      expect(cache.get<String>('key_miss'), equals('fetched_data'));
    });

    test('Stale-while-revalidate returns stale data instantly and refreshes in background', () async {
      final cache = CacheService();
      cache.set('swr_key', 'stale_value', ttl: const Duration(milliseconds: 10));
      await Future.delayed(const Duration(milliseconds: 20));

      final completer = Completer<String>();
      final result = await cache.getOrFetch(
        'swr_key',
        () => completer.future,
        staleWhileRevalidate: true,
      );

      // Should immediately receive the stale data without waiting for completer!
      expect(result, equals('stale_value'));

      // Complete background refresh
      completer.complete('fresh_value');
      await Future.delayed(const Duration(milliseconds: 10));

      // Next read gets fresh value
      expect(cache.get<String>('swr_key'), equals('fresh_value'));
    });

    test('Timeout protection falls back to fallback or stale without throwing', () async {
      final cache = CacheService();

      final result = await cache.getOrFetch<String>(
        'slow_key',
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'slow_data';
        },
        timeout: const Duration(milliseconds: 20),
        fallback: 'fallback_data',
      );

      expect(result, equals('fallback_data'));
    });

    test('Invalidation removes targeted key or prefix', () {
      final cache = CacheService();
      cache.set('stats_total', 100);
      cache.set('stats_today', 25);
      cache.set('user_profile', 'John');

      cache.invalidate('user_profile');
      expect(cache.get<String>('user_profile'), isNull);
      expect(cache.get<int>('stats_total'), equals(100));

      cache.invalidatePrefix('stats_');
      expect(cache.get<int>('stats_total'), isNull);
      expect(cache.get<int>('stats_today'), isNull);
    });
  });

  group('StatsRepository & UserProfileRepository Caching Tests', () {
    test('StatsRepository optimistic update populates cache', () async {
      final repo = StatsRepository();
      repo.updateOptimistic(const UserStats(
        totalXp: 500,
        todayXp: 75,
        level: 3,
        streakDays: 5,
      ));

      final stats = await repo.getUserStats();
      expect(stats.totalXp, equals(500));
      expect(stats.todayXp, equals(75));
      expect(stats.level, equals(3));
      expect(stats.streakDays, equals(5));
    });

    test('UserProfileRepository reads from cache on second read', () async {
      final profileRepo = UserProfileRepository();
      await profileRepo.saveProfile('Commander Shepard', 'Spectre');

      final profile = await profileRepo.getProfile();
      expect(profile.name, equals('Commander Shepard'));
      expect(profile.title, equals('Spectre'));
    });
  });
}
