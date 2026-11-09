import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Custom lightweight drag slider for spectrum gradients.
/// Avoids Material [Slider] internal [OverlayPortal] semantics issues on desktop platforms.
class ColorTrackSlider extends StatelessWidget {
  const ColorTrackSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.gradient,
  });

  final double value; // 0.0 to 1.0
  final ValueChanged<double> onChanged;
  final Gradient gradient;

  void _handleDrag(Offset localPosition, double totalWidth) {
    const thumbDiameter = 22.0;
    final availableWidth = totalWidth - thumbDiameter;
    if (availableWidth <= 0) return;
    final clampedX =
        (localPosition.dx - (thumbDiameter / 2)).clamp(0.0, availableWidth);
    final ratio = clampedX / availableWidth;
    onChanged(ratio.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const thumbDiameter = 22.0;
        final availableWidth =
            (totalWidth - thumbDiameter).clamp(1.0, double.infinity);
        final leftOffset = (value.clamp(0.0, 1.0) * availableWidth);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _handleDrag(details.localPosition, totalWidth),
          onPanUpdate: (details) =>
              _handleDrag(details.localPosition, totalWidth),
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: gradient,
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: leftOffset,
                  child: Container(
                    width: thumbDiameter,
                    height: thumbDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.black38, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

