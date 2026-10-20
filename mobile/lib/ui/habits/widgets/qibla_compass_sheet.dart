import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/location_service.dart';
import 'package:axis/data/qibla_service.dart';

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
    final qiblaBearing = _qiblaService.calculateQiblaBearing(_latitude, _longitude);
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
                      const Text(
                        'QIBLA DIRECTION',
                        style: TextStyle(
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
                            _isGps ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
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

                      // Trigger haptic feedback when entering aligned zone
                      if (status.isFacingQibla) {
                        if (!_hapticFired) {
                          HapticFeedback.selectionClick();
                          _hapticFired = true;
                        }
                      } else {
                        _hapticFired = false;
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          children: [
                            // Alignment Status Pill
                            _buildAlignmentBanner(status),
                            const SizedBox(height: 24),

                            // Interactive Compass Gauge
                            _buildCompassDial(status),
                            const SizedBox(height: 24),

                            // Readouts Grid
                            _buildReadoutsGrid(status, qiblaBearing, distanceKm),
                            const SizedBox(height: 16),

                            // Calibration Notice
                            _buildCalibrationFooter(),
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

  Widget _buildAlignmentBanner(QiblaStatus status) {
    final isFacing = status.isFacingQibla;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isFacing
            ? AxisColors.success.withValues(alpha: 0.22)
            : AxisColors.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFacing
              ? AxisColors.success.withValues(alpha: 0.7)
              : AxisColors.borderSubtle,
          width: isFacing ? 1.5 : 1,
        ),
        boxShadow: isFacing
            ? [
                BoxShadow(
                  color: AxisColors.success.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFacing ? Icons.check_circle_rounded : Icons.navigation_rounded,
            size: 16,
            color: isFacing ? AxisColors.success : AxisColors.secondary,
          ),
          const SizedBox(width: 8),
          Text(
            isFacing
                ? 'Facing the Holy Kaaba'
                : _formatTurnGuidance(status.qiblaOffset),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isFacing ? AxisColors.success : AxisColors.textHigh,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTurnGuidance(double offset) {
    if (offset > 180) {
      final turnLeft = (360 - offset).round();
      return 'Turn $turnLeft° Left toward Kaaba';
    } else {
      final turnRight = offset.round();
      return 'Turn $turnRight° Right toward Kaaba';
    }
  }

  Widget _buildCompassDial(QiblaStatus status) {
    final isFacing = status.isFacingQibla;
    final headingRad = -(status.deviceHeading * (math.pi / 180.0));
    final qiblaRad = (status.qiblaBearing * (math.pi / 180.0));

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating outer compass dial (North, East, South, West)
          Transform.rotate(
            angle: headingRad,
            child: SizedBox(
              width: 250,
              height: 250,
              child: CustomPaint(
                painter: _CompassDialPainter(isAligned: isFacing),
              ),
            ),
          ),

          // Kaaba Marker on the outer rim
          Transform.rotate(
            angle: headingRad + qiblaRad,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isFacing ? AxisColors.success : const Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (isFacing ? AxisColors.success : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mosque_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Central Arrow pointing towards Kaaba relative to phone
          Transform.rotate(
            angle: (status.qiblaOffset * (math.pi / 180.0)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.navigation_rounded,
                  size: 44,
                  color: isFacing ? AxisColors.success : AxisColors.secondary,
                  shadows: [
                    Shadow(
                      color: (isFacing ? AxisColors.success : AxisColors.secondary)
                          .withValues(alpha: 0.6),
                      blurRadius: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Center Hub
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A2B),
              shape: BoxShape.circle,
              border: Border.all(
                color: isFacing ? AxisColors.success : AxisColors.borderPrimary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${status.deviceHeading.round()}°',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isFacing ? AxisColors.success : AxisColors.textHigh,
                    ),
                  ),
                  Text(
                    status.cardinalDirection,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isFacing ? AxisColors.success : AxisColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadoutsGrid(
      QiblaStatus status, double qiblaBearing, int distanceKm) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'QIBLA ANGLE',
            value: '${qiblaBearing.toStringAsFixed(1)}°',
            subtext: 'Bearing from North',
            icon: Icons.my_location_rounded,
            accentColor: AxisColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'HEADING',
            value: '${status.deviceHeading.round()}° ${status.cardinalDirection}',
            subtext: 'Current Direction',
            icon: Icons.explore_rounded,
            accentColor: AxisColors.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: 'DISTANCE',
            value: '$distanceKm km',
            subtext: 'To Mecca',
            icon: Icons.place_rounded,
            accentColor: AxisColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AxisColors.textHigh,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: AxisColors.textDim,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, size: 14, color: AxisColors.textDim),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hold device flat and move in a figure-8 motion for optimal compass calibration.',
              style: TextStyle(fontSize: 10, color: AxisColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws accurate compass tick marks and cardinal points
class _CompassDialPainter extends CustomPainter {
  final bool isAligned;

  const _CompassDialPainter({required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer circle
    final outerPaint = Paint()
      ..color = isAligned
          ? AxisColors.success.withValues(alpha: 0.5)
          : AxisColors.borderPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius - 4, outerPaint);

    // Degree tick marks
    final majorTickPaint = Paint()
      ..color = AxisColors.textHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final minorTickPaint = Paint()
      ..color = AxisColors.borderGlass2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int degree = 0; degree < 360; degree += 5) {
      final rad = degree * (math.pi / 180.0);
      final isMajor = degree % 30 == 0;
      final isCardinal = degree % 90 == 0;

      if (isCardinal) continue; // Drawn as text below

      final tickLength = isMajor ? 8.0 : 4.0;
      final startR = radius - 6;
      final endR = startR - tickLength;

      final start = Offset(
        center.dx + startR * math.sin(rad),
        center.dy - startR * math.cos(rad),
      );
      final end = Offset(
        center.dx + endR * math.sin(rad),
        center.dy - endR * math.cos(rad),
      );

      canvas.drawLine(start, end, isMajor ? majorTickPaint : minorTickPaint);
    }

    // Cardinal Points (N, E, S, W)
    _drawCardinal(canvas, center, radius - 20, 'N', const Color(0xFFEF4444));
    _drawCardinal(canvas, center, radius - 20, 'E', AxisColors.textHigh, angle: 90);
    _drawCardinal(canvas, center, radius - 20, 'S', AxisColors.textHigh, angle: 180);
    _drawCardinal(canvas, center, radius - 20, 'W', AxisColors.textHigh, angle: 270);
  }

  void _drawCardinal(
      Canvas canvas, Offset center, double r, String text, Color color,
      {double angle = 0}) {
    final rad = angle * (math.pi / 180.0);
    final pos = Offset(
      center.dx + r * math.sin(rad),
      center.dy - r * math.cos(rad),
    );

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned;
}
