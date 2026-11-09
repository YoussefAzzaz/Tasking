import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../cyber_color_picker.dart';

/// Custom painter to guarantee mathematical 100% centering of the plus sign
/// with no font metric baseline/descent offsets.
class CenteredPlusPainter extends CustomPainter {
  final Color color;
  final double length;
  final double strokeWidth;

  const CenteredPlusPainter({
    required this.color,
    required this.length,
    this.strokeWidth = 1.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = length / 2;

    // Horizontal bar
    canvas.drawLine(Offset(cx - half, cy), Offset(cx + half, cy), paint);
    // Vertical bar
    canvas.drawLine(Offset(cx, cy - half), Offset(cx, cy + half), paint);
  }

  @override
  bool shouldRepaint(covariant CenteredPlusPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.length != length ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Reusable empty round button with rainbow border and centered plus icon.
/// Tapping opens the [CyberColorPickerDialog].
class RainbowColorPickerButton extends StatelessWidget {
  const RainbowColorPickerButton({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.size = 36.0,
    this.borderWidth = 2.5,
  });

  final String selectedColor;
  final ValueChanged<String> onColorSelected;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = (size <= 26) ? 1.5 : borderWidth;
    final plusLength = (size <= 26) ? 7.0 : (size <= 32 ? 9.0 : 12.0);
    final plusStroke = (size <= 26) ? 1.3 : 1.6;

    return InkWell(
      onTap: () async {
        final picked = await showDialog<String>(
          context: context,
          builder: (ctx) => CyberColorPickerDialog(
            initialColorHex: selectedColor,
          ),
        );
        if (picked != null && picked.isNotEmpty) {
          onColorSelected(picked);
        }
      },
      borderRadius: BorderRadius.circular(size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.cyan,
                Colors.blue,
                Colors.purple,
                Colors.pink,
                Colors.red,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(effectiveBorder),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AxisColors.surfaceLow,
              ),
              child: Center(
                child: CustomPaint(
                  size: Size(plusLength, plusLength),
                  painter: CenteredPlusPainter(
                    color: AxisColors.textHigh,
                    length: plusLength,
                    strokeWidth: plusStroke,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

