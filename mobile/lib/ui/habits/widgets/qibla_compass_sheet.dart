import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/location_service.dart';
import 'package:axis/data/qibla_service.dart';
import 'compass/qibla_compass_dial.dart';
import 'compass/qibla_metrics_widgets.dart';

export 'compass/qibla_compass_dial.dart';
export 'compass/qibla_metrics_widgets.dart';

/// Interactive modal sheet displaying a high-precision Qibla compass
/// powered by flutter_compass and geolocator.
class QiblaCompassSheet extends StatefulWidget {
  const QiblaCompassSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QiblaCompassSheet(),
    );
  }

  @override
  State<QiblaCompassSheet> createState() => _QiblaCompassSheetState();
}

class _QiblaCompassSheetState extends State<QiblaCompassSheet> {
  final _qiblaService = QiblaService();
  final _locationService = LocationService();

  double _latitude = 35.7065;
  double _longitude = -0.6292;
  String _city = 'Local';
  bool _isGps = false;
  bool _loading = true;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final loc = await _locationService.getLocation();
    if (mounted) {
      setState(() {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        _city = loc.city;
        _isGps = loc.isGps;
        _loading = false;
      });
    }
  }

  /// Calculates spherical distance to Mecca in kilometers
  int _distanceToKaabaKm() {
    const kaabaLat = 21.422487;
    const kaabaLon = 39.826206;
    const earthRadiusKm = 6371.0;

    final dLat = (_latitude - kaabaLat) * (math.pi / 180.0);
    final dLon = (_longitude - kaabaLon) * (math.pi / 180.0);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_latitude * (math.pi / 180.0)) *
            math.cos(kaabaLat * (math.pi / 180.0)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (earthRadiusKm * c).round();
  }

  @override
  Widget build(BuildContext context) {
    final qiblaBearing =
        _qiblaService.calculateQiblaBearing(_latitude, _longitude);
    final distanceKm = _distanceToKaabaKm();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF508111D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AxisColors.borderGlass2,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AxisColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AxisColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.explore_rounded,
                    color: AxisColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.isArabic ? 'اتجاه القبلة' : 'QIBLA DIRECTION',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.textHigh,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            _isGps
                                ? Icons.gps_fixed_rounded
                                : Icons.location_on_rounded,
                            size: 11,
                            color: AxisColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$_city (${_latitude.toStringAsFixed(2)}°, ${_longitude.toStringAsFixed(2)}°)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AxisColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AxisColors.textMuted, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AxisColors.borderSubtle, height: 1),

          // Compass Body
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AxisColors.success),
                  )
                : StreamBuilder<QiblaStatus>(
                    stream: _qiblaService.watchQibla(
                      latitude: _latitude,
                      longitude: _longitude,
                    ),
                    builder: (context, snapshot) {
                      final status = snapshot.data ??
                          QiblaStatus(
                            deviceHeading: 0,
                            qiblaBearing: qiblaBearing,
                            qiblaOffset: qiblaBearing,
                            isFacingQibla: false,
                          );

                      // Trigger haptic feedback when entering aligned zone safely post-frame
                      if (status.isFacingQibla != _hapticFired) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          if (status.isFacingQibla && !_hapticFired) {
                            HapticFeedback.selectionClick();
                            _hapticFired = true;
                          } else if (!status.isFacingQibla && _hapticFired) {
                            _hapticFired = false;
                          }
                        });
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          children: [
                            // Alignment Status Pill
                            QiblaAlignmentBanner(status: status),
                            const SizedBox(height: 24),

                            // Interactive Compass Gauge
                            QiblaCompassDial(status: status),
                            const SizedBox(height: 24),

                            // Readouts Grid
                            QiblaReadoutsGrid(
                              status: status,
                              qiblaBearing: qiblaBearing,
                              distanceKm: distanceKm,
                            ),
                            const SizedBox(height: 16),

                            // Calibration Notice
                            const QiblaCalibrationFooter(),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
