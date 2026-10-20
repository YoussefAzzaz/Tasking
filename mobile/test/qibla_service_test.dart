import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/qibla_service.dart';
import 'package:axis/data/location_service.dart';

void main() {
  group('Qibla Direction & Geolocation Service Tests', () {
    final qiblaService = QiblaService();

    test('Qibla bearing calculates accurately across multiple global cities', () {
      // Cairo, Egypt (Lat: 30.0444, Lng: 31.2357) -> Mecca is ESE (~136 degrees)
      final cairoQibla = qiblaService.calculateQiblaBearing(30.0444, 31.2357);
      expect(cairoQibla, greaterThan(130));
      expect(cairoQibla, lessThan(142));

      // Oran / Algiers, Algeria (Lat: 35.7065, Lng: -0.6292) -> Mecca is ESE (~107 degrees)
      final oranQibla = qiblaService.calculateQiblaBearing(35.7065, -0.6292);
      expect(oranQibla, greaterThan(100));
      expect(oranQibla, lessThan(115));

      // London, UK (Lat: 51.5074, Lng: -0.1278) -> Mecca is ESE (~119 degrees)
      final londonQibla = qiblaService.calculateQiblaBearing(51.5074, -0.1278);
      expect(londonQibla, greaterThan(115));
      expect(londonQibla, lessThan(125));

      // New York, USA (Lat: 40.7128, Lng: -74.0060) -> Mecca Great Circle is ENE (~58 degrees)
      final nyQibla = qiblaService.calculateQiblaBearing(40.7128, -74.0060);
      expect(nyQibla, greaterThan(50));
      expect(nyQibla, lessThan(65));

      // Jakarta, Indonesia (Lat: -6.2088, Lng: 106.8456) -> Mecca is WNW (~295 degrees)
      final jakartaQibla = qiblaService.calculateQiblaBearing(-6.2088, 106.8456);
      expect(jakartaQibla, greaterThan(290));
      expect(jakartaQibla, lessThan(300));
    });

    test('QiblaStatus calculates correct cardinal direction strings', () {
      const northStatus = QiblaStatus(
        deviceHeading: 0.0,
        qiblaBearing: 107.0,
        qiblaOffset: 107.0,
        isFacingQibla: false,
      );
      expect(northStatus.cardinalDirection, 'N');

      const eastStatus = QiblaStatus(
        deviceHeading: 90.0,
        qiblaBearing: 107.0,
        qiblaOffset: 17.0,
        isFacingQibla: false,
      );
      expect(eastStatus.cardinalDirection, 'E');

      const southStatus = QiblaStatus(
        deviceHeading: 180.0,
        qiblaBearing: 107.0,
        qiblaOffset: 287.0,
        isFacingQibla: false,
      );
      expect(southStatus.cardinalDirection, 'S');

      const westStatus = QiblaStatus(
        deviceHeading: 270.0,
        qiblaBearing: 107.0,
        qiblaOffset: 197.0,
        isFacingQibla: false,
      );
      expect(westStatus.cardinalDirection, 'W');
    });

    test('QiblaStatus detects aligned state when within tolerance', () {
      const alignedStatus = QiblaStatus(
        deviceHeading: 107.5,
        qiblaBearing: 107.0,
        qiblaOffset: 0.5,
        isFacingQibla: true,
      );
      expect(alignedStatus.isFacingQibla, isTrue);

      const wrappedAlignedStatus = QiblaStatus(
        deviceHeading: 106.0,
        qiblaBearing: 107.0,
        qiblaOffset: 359.0,
        isFacingQibla: true,
      );
      expect(wrappedAlignedStatus.isFacingQibla, isTrue);

      const unalignedStatus = QiblaStatus(
        deviceHeading: 45.0,
        qiblaBearing: 107.0,
        qiblaOffset: 62.0,
        isFacingQibla: false,
      );
      expect(unalignedStatus.isFacingQibla, isFalse);
    });

    test('AppLocation models support all location sources', () {
      const gpsLocation = AppLocation(
        latitude: 35.7065,
        longitude: -0.6292,
        city: 'Oran',
        country: 'Algeria',
        source: LocationSource.gps,
      );
      expect(gpsLocation.isGps, isTrue);
      expect(gpsLocation.source, LocationSource.gps);

      const ipLocation = AppLocation(
        latitude: 36.7538,
        longitude: 3.0588,
        city: 'Algiers',
        country: 'Algeria',
        source: LocationSource.ipGeolocation,
      );
      expect(ipLocation.isGps, isFalse);
      expect(ipLocation.source, LocationSource.ipGeolocation);
    });
  });
}
