import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:adhan_dart/adhan_dart.dart';

/// Representation of the real-time Qibla alignment status
class QiblaStatus {
  final double deviceHeading;
  final double qiblaBearing;
  final double qiblaOffset;
  final bool isFacingQibla;
  final double? accuracy;

  const QiblaStatus({
    required this.deviceHeading,
    required this.qiblaBearing,
    required this.qiblaOffset,
    required this.isFacingQibla,
    this.accuracy,
  });

  /// Cardinal direction string (e.g. N, NNE, NE, ENE, E, ...)
  String get cardinalDirection {
    const directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
    ];
    final index = ((deviceHeading + 11.25) % 360 / 22.5).floor();
    return directions[index % 16];
  }
}

/// Service dedicated to accurate Qibla direction calculation and live compass tracking
class QiblaService {
  static final QiblaService _instance = QiblaService._();
  factory QiblaService() => _instance;
  QiblaService._();

  /// Calculates the exact Great Circle Qibla bearing towards the Kaaba (21.422487° N, 39.826206° E)
  /// given geographical coordinates
  double calculateQiblaBearing(double latitude, double longitude) {
    try {
      final coords = Coordinates(latitude, longitude);
      final bearing = Qibla.qibla(coords);
      return (bearing + 360) % 360;
    } catch (_) {
      return _calculateSphericalQibla(latitude, longitude);
    }
  }

  /// High-precision spherical trigonometry fallback for Qibla bearing
  double _calculateSphericalQibla(double lat, double lon) {
    const kaabaLat = 21.422487;
    const kaabaLon = 39.826206;

    final phi1 = lat * (math.pi / 180.0);
    final phi2 = kaabaLat * (math.pi / 180.0);
    final deltaLambda = (kaabaLon - lon) * (math.pi / 180.0);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final bearing = math.atan2(y, x) * (180.0 / math.pi);
    return (bearing + 360.0) % 360.0;
  }

  /// Checks if hardware compass sensor is supported on this device
  bool get isCompassSupported => FlutterCompass.events != null;

  /// Stream of live Qibla alignment updates based on the device's compass and location
  Stream<QiblaStatus> watchQibla({required double latitude, required double longitude}) {
    final qiblaBearing = calculateQiblaBearing(latitude, longitude);
    final compassStream = FlutterCompass.events;

    if (compassStream == null) {
      return Stream.value(
        QiblaStatus(
          deviceHeading: 0,
          qiblaBearing: qiblaBearing,
          qiblaOffset: qiblaBearing,
          isFacingQibla: false,
        ),
      );
    }

    return compassStream.map((event) {
      final heading = (event.heading ?? 0.0);
      final normalizedHeading = (heading + 360.0) % 360.0;
      final offset = (qiblaBearing - normalizedHeading + 360.0) % 360.0;

      // Facing Qibla within +/- 3 degrees tolerance
      final isFacing = offset <= 3.0 || offset >= 357.0;

      return QiblaStatus(
        deviceHeading: normalizedHeading,
        qiblaBearing: qiblaBearing,
        qiblaOffset: offset,
        isFacingQibla: isFacing,
        accuracy: event.accuracy,
      );
    });
  }
}
