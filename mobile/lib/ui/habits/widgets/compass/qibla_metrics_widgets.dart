import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/qibla_service.dart';

/// Alignment banner indicating whether device is facing Kaaba or turn direction needed.
class QiblaAlignmentBanner extends StatelessWidget {
  const QiblaAlignmentBanner({
    super.key,
    required this.status,
  });

  final QiblaStatus status;

  String _formatTurnGuidance(double offset, bool isArabic) {
    if (offset > 180) {
      final turnLeft = (360 - offset).round();
      return isArabic
          ? 'استدر $turnLeft° يساراً نحو الكعبة'
          : 'Turn $turnLeft° Left toward Kaaba';
    } else {
      final turnRight = offset.round();
      return isArabic
          ? 'استدر $turnRight° يميناً نحو الكعبة'
          : 'Turn $turnRight° Right toward Kaaba';
    }
  }

  static String localizedCardinal(String cardinal, bool isArabic) {
    if (!isArabic) return cardinal;
    switch (cardinal.toUpperCase()) {
      case 'N':
        return 'شمال';
      case 'NE':
      case 'NNE':
      case 'ENE':
        return 'ش.ق';
      case 'E':
        return 'شرق';
      case 'SE':
      case 'ESE':
      case 'SSE':
        return 'ج.ق';
      case 'S':
        return 'جنوب';
      case 'SW':
      case 'SSW':
      case 'WSW':
        return 'ج.غ';
      case 'W':
        return 'غرب';
      case 'NW':
      case 'WNW':
      case 'NNW':
        return 'ش.غ';
      default:
        return cardinal;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                ? (context.isArabic
                    ? 'أنت الآن في اتجاه الكعبة المشرفة'
                    : 'Facing the Holy Kaaba')
                : _formatTurnGuidance(status.qiblaOffset, context.isArabic),
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
}

/// 3-column readout tiles for Qibla Angle, Current Heading, and Distance to Mecca.
class QiblaReadoutsGrid extends StatelessWidget {
  const QiblaReadoutsGrid({
    super.key,
    required this.status,
    required this.qiblaBearing,
    required this.distanceKm,
  });

  final QiblaStatus status;
  final double qiblaBearing;
  final int distanceKm;

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

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: isArabic ? 'زاوية القبلة' : 'QIBLA ANGLE',
            value: '${qiblaBearing.toStringAsFixed(1)}°',
            subtext: isArabic ? 'الانحراف عن الشمال' : 'Bearing from North',
            icon: Icons.my_location_rounded,
            accentColor: AxisColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: isArabic ? 'الاتجاه الحالي' : 'HEADING',
            value:
                '${status.deviceHeading.round()}° ${QiblaAlignmentBanner.localizedCardinal(status.cardinalDirection, isArabic)}',
            subtext: isArabic ? 'الاتجاه الفعلي' : 'Current Direction',
            icon: Icons.explore_rounded,
            accentColor: AxisColors.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricTile(
            label: isArabic ? 'المسافة' : 'DISTANCE',
            value: isArabic ? '$distanceKm كم' : '$distanceKm km',
            subtext: isArabic ? 'إلى مكة المكرمة' : 'To Mecca',
            icon: Icons.place_rounded,
            accentColor: AxisColors.warning,
          ),
        ),
      ],
    );
  }
}

/// Compass calibration advisory footer banner.
class QiblaCalibrationFooter extends StatelessWidget {
  const QiblaCalibrationFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 14, color: AxisColors.textDim),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.isArabic
                  ? 'امسك الجهاز بشكل مستوٍ وحركه على شكل رقم 8 لمعايرة البوصلة بأفضل دقة.'
                  : 'Hold device flat and move in a figure-8 motion for optimal compass calibration.',
              style: const TextStyle(fontSize: 10, color: AxisColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

