import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Origin source of the resolved geographical coordinates
enum LocationSource {
  gps,
  ipGeolocation,
  timezoneInference,
}

/// Strongly typed geolocation result
class AppLocation {
  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final LocationSource source;

  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    required this.source,
  });

  bool get isGps => source == LocationSource.gps;

  @override
  String toString() =>
      'AppLocation(lat: $latitude, lon: $longitude, city: $city, country: $country, source: $source)';
}

/// Service dedicated to accurate geolocation retrieval using geolocator,
/// with multi-layer fallback to IP geolocation and device timezone inference.
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  AppLocation? _cachedLocation;

  AppLocation? get cachedLocation => _cachedLocation;

  /// Resolves the user's location with priority:
  /// 1. Hardware GPS via geolocator (accurate to meters)
  /// 2. IP Geolocation via ip-api.com (city accuracy)
  /// 3. Device timezone offset mapping (regional accuracy)
  Future<AppLocation> getLocation({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedLocation != null) {
      return _cachedLocation!;
    }

    // 1. Attempt GPS Geolocation
    final gpsLocation = await _tryGpsLocation();
    if (gpsLocation != null) {
      _cachedLocation = gpsLocation;
      return gpsLocation;
    }

    // 2. Attempt IP Geolocation fallback
    final ipLocation = await _tryIpGeolocation();
    if (ipLocation != null) {
      _cachedLocation = ipLocation;
      return ipLocation;
    }

    // 3. Fallback to Timezone Offset Inference
    final timezoneLocation = _fallbackTimezoneLocation();
    _cachedLocation = timezoneLocation;
    return timezoneLocation;
  }

  /// Attempts to get high accuracy position via hardware GPS
  Future<AppLocation?> _tryGpsLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Check last known position first for instant response
      Position? position = await Geolocator.getLastKnownPosition();

      // If null or stale, get fresh high-accuracy position with 6-second timeout
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );

      // Resolve human-readable city name from cached location or fast IP lookup
      String resolvedCity = _cachedLocation?.city ?? '';
      String resolvedCountry = _cachedLocation?.country ?? '';

      if (resolvedCity.isEmpty || resolvedCity == 'GPS Location' || resolvedCity == 'Local') {
        try {
          final ipLoc = await _tryIpGeolocation();
          if (ipLoc != null && ipLoc.city.isNotEmpty && ipLoc.city != 'Local') {
            resolvedCity = ipLoc.city;
            resolvedCountry = ipLoc.country;
          }
        } catch (_) {}
      }

      if (resolvedCity.isEmpty || resolvedCity == 'GPS Location') {
        final offset = _fallbackTimezoneLocation();
        resolvedCity = offset.city;
        resolvedCountry = offset.country;
      }

      return AppLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        city: resolvedCity,
        country: resolvedCountry,
        source: LocationSource.gps,
      );
    } catch (e) {
      debugPrint('Geolocator GPS location failed: $e');
      return null;
    }
  }

  /// Attempts IP-based geolocation fallback
  Future<AppLocation?> _tryIpGeolocation() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('http://ip-api.com/json'));
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        if (data['status'] == 'success') {
          return AppLocation(
            latitude: (data['lat'] as num).toDouble(),
            longitude: (data['lon'] as num).toDouble(),
            city: (data['city'] as String?) ?? 'Local',
            country: (data['country'] as String?) ?? '',
            source: LocationSource.ipGeolocation,
          );
        }
      }
    } catch (_) {
      // Network unavailable or timed out
    }
    return null;
  }

  /// Regional fallback based on device timezone offset
  AppLocation _fallbackTimezoneLocation() {
    final offsetHours = DateTime.now().timeZoneOffset.inHours;

    switch (offsetHours) {
      case 1:
        return const AppLocation(
          latitude: 35.7065,
          longitude: -0.6292,
          city: 'North Africa (GMT+1)',
          country: 'Algeria',
          source: LocationSource.timezoneInference,
        );
      case 2:
        return const AppLocation(
          latitude: 30.0444,
          longitude: 31.2357,
          city: 'Cairo Region (GMT+2)',
          country: 'Egypt',
          source: LocationSource.timezoneInference,
        );
      case 3:
        return const AppLocation(
          latitude: 21.4225,
          longitude: 39.8262,
          city: 'Makkah Region (GMT+3)',
          country: 'Saudi Arabia',
          source: LocationSource.timezoneInference,
        );
      case 4:
        return const AppLocation(
          latitude: 25.2048,
          longitude: 55.2708,
          city: 'Dubai Region (GMT+4)',
          country: 'United Arab Emirates',
          source: LocationSource.timezoneInference,
        );
      case 5:
        return const AppLocation(
          latitude: 24.8607,
          longitude: 67.0011,
          city: 'Karachi Region (GMT+5)',
          country: 'Pakistan',
          source: LocationSource.timezoneInference,
        );
      case 6:
        return const AppLocation(
          latitude: 23.8103,
          longitude: 90.4125,
          city: 'Dhaka Region (GMT+6)',
          country: 'Bangladesh',
          source: LocationSource.timezoneInference,
        );
      case 7:
        return const AppLocation(
          latitude: -6.2088,
          longitude: 106.8456,
          city: 'Jakarta Region (GMT+7)',
          country: 'Indonesia',
          source: LocationSource.timezoneInference,
        );
      case 8:
        return const AppLocation(
          latitude: 3.1390,
          longitude: 101.6869,
          city: 'Kuala Lumpur (GMT+8)',
          country: 'Malaysia',
          source: LocationSource.timezoneInference,
        );
      case 0:
        return const AppLocation(
          latitude: 33.5731,
          longitude: -7.5898,
          city: 'Casablanca (GMT)',
          country: 'Morocco',
          source: LocationSource.timezoneInference,
        );
      case -5:
        return const AppLocation(
          latitude: 40.7128,
          longitude: -74.0060,
          city: 'New York (EST)',
          country: 'United States',
          source: LocationSource.timezoneInference,
        );
      case -6:
        return const AppLocation(
          latitude: 41.8781,
          longitude: -87.6298,
          city: 'Chicago (CST)',
          country: 'United States',
          source: LocationSource.timezoneInference,
        );
      case -8:
        return const AppLocation(
          latitude: 34.0522,
          longitude: -118.2437,
          city: 'Los Angeles (PST)',
          country: 'United States',
          source: LocationSource.timezoneInference,
        );
      default:
        return const AppLocation(
          latitude: 21.4225,
          longitude: 39.8262,
          city: 'Makkah Region',
          country: 'Saudi Arabia',
          source: LocationSource.timezoneInference,
        );
    }
  }
}
