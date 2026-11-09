import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';

/// Cyber-minimalist Image Crop & Reframe Dialog
/// Allows panning, scaling (pinch or slider), and rotating an avatar image
/// before saving with crisp circular boundary extraction.
class ImageCropDialog extends StatefulWidget {
  const ImageCropDialog({
    super.key,
    required this.imageBytes,
  });

  final Uint8List imageBytes;

  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List imageBytes,
  }) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push<Uint8List>(
      PageRouteBuilder<Uint8List>(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (ctx, anim, secAnim) => FadeTransition(
          opacity: anim,
          child: ImageCropDialog(imageBytes: imageBytes),
        ),
      ),
    );
  }

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final GlobalKey _cropBoundaryKey = GlobalKey();
  late final TransformationController _transformationController;

  double _scale = 1.0;
  int _rotation = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (mounted && (_scale - currentScale).abs() > 0.05) {
      setState(() {
        _scale = currentScale.clamp(1.0, 3.5);
      });
    }
  }

  void _onSliderChanged(double newScale) {
    setState(() {
      _scale = newScale;
    });

    final current = _transformationController.value;
    final tx = current.storage[12];
    final ty = current.storage[13];

    final matrix = Matrix4.identity();
    matrix.storage[0] = newScale;
    matrix.storage[5] = newScale;
    matrix.storage[12] = tx;
    matrix.storage[13] = ty;
    _transformationController.value = matrix;
  }

  void _rotateClockwise() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotation = (_rotation + 1) % 4;
    });
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _rotation = 0;
      _scale = 1.0;
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _applyCrop() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      HapticFeedback.mediumImpact();
      final boundary = _cropBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary != null) {
        final uiImage = await boundary.toImage(pixelRatio: 2.5);
        final byteData =
            await uiImage.toByteData(format: ui.ImageByteFormat.png);

        if (byteData != null) {
          final cropped = byteData.buffer.asUint8List();
          if (mounted) {
            Navigator.of(context).pop(cropped);
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback safely to original bytes if boundary capture fails
    if (mounted) {
      Navigator.of(context).pop(widget.imageBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final size = MediaQuery.of(context).size;
    final apertureSize = math.min(size.width * 0.76, 280.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: SafeArea(
        child: Column(
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AxisColors.textHigh),
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(null),
                    tooltip: isArabic ? 'إلغاء' : 'Cancel',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'قص وتعديل الإطار' : 'Crop & Reframe',
                          style: const TextStyle(
                            color: AxisColors.textHigh,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isArabic
                              ? 'قرّب أو اسحب لمحاذاة الصورة في الإطار'
                              : 'Pinch or drag to align avatar in frame',
                          style: TextStyle(
                            color: AxisColors.textMuted.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isProcessing ? null : _reset,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 16, color: AxisColors.primarySoft),
                    label: Text(
                      isArabic ? 'إعادة ضبط' : 'Reset',
                      style: const TextStyle(
                        color: AxisColors.primarySoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Central Interactive Viewfinder
            Center(
              child: SizedBox(
                width: apertureSize,
                height: apertureSize,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Captured Circular Repaint Boundary
                    RepaintBoundary(
                      key: _cropBoundaryKey,
                      child: ClipOval(
                        child: Container(
                          width: apertureSize,
                          height: apertureSize,
                          color: AxisColors.canvasBase,
                          child: Transform.rotate(
                            angle: _rotation * (math.pi / 2),
                            child: InteractiveViewer(
                              transformationController:
                                  _transformationController,
                              minScale: 0.8,
                              maxScale: 4.0,
                              boundaryMargin: const EdgeInsets.all(240),
                              clipBehavior: Clip.none,
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Decorative Viewfinder Reticle Overlay (Excluded from capture)
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(apertureSize, apertureSize),
                        painter: _ViewfinderOverlayPainter(
                          apertureRadius: apertureSize / 2,
                        ),
                      ),
                    ),

                    // Corner brackets
                    IgnorePointer(
                      child: SizedBox(
                        width: apertureSize + 16,
                        height: apertureSize + 16,
                        child: CustomPaint(
                          painter: _CyberCornerPainter(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Zoom Slider & Rotate Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.zoom_out_rounded,
                          color: AxisColors.textDim, size: 18),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AxisColors.primary,
                            inactiveTrackColor: AxisColors.surfaceHigh,
                            thumbColor: AxisColors.primarySoft,
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: _scale,
                            min: 1.0,
                            max: 3.5,
                            onChanged: _isProcessing ? null : _onSliderChanged,
                          ),
                        ),
                      ),
                      const Icon(Icons.zoom_in_rounded,
                          color: AxisColors.textDim, size: 18),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AxisColors.textHigh,
                          side: const BorderSide(
                              color: AxisColors.borderPrimary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: _isProcessing ? null : _rotateClockwise,
                        icon: const Icon(Icons.rotate_right_rounded,
                            size: 16, color: AxisColors.primarySoft),
                        label: Text(
                          isArabic ? 'تدوير ${_rotation * 90}°' : 'Rotate ${_rotation * 90}°',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Bottom Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: AxisColors.surfaceLow,
                border: Border(
                  top: BorderSide(color: AxisColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AxisColors.textMuted,
                        side: const BorderSide(
                            color: AxisColors.borderSubtle),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(null),
                      child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AxisColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AxisColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isProcessing ? null : _applyCrop,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isProcessing
                            ? (isArabic ? 'جاري المعالجة...' : 'Processing...')
                            : (isArabic ? 'تطبيق وحفظ' : 'Apply & Save'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the circular ring and faint rule-of-thirds grid lines
class _ViewfinderOverlayPainter extends CustomPainter {
  _ViewfinderOverlayPainter({required this.apertureRadius});
  final double apertureRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Glowing cyan circle border
    final ringPaint = Paint()
      ..color = AxisColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, apertureRadius, ringPaint);

    // Subtle rule-of-thirds grid within circle
    final gridPaint = Paint()
      ..color = AxisColors.primary.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: apertureRadius));

    canvas.save();
    canvas.clipPath(clipPath);

    final thirdW = size.width / 3;
    final thirdH = size.height / 3;

    // Vertical lines
    canvas.drawLine(
        Offset(thirdW, 0), Offset(thirdW, size.height), gridPaint);
    canvas.drawLine(
        Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), gridPaint);

    // Horizontal lines
    canvas.drawLine(
        Offset(0, thirdH), Offset(size.width, thirdH), gridPaint);
    canvas.drawLine(
        Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), gridPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) =>
      oldDelegate.apertureRadius != apertureRadius;
}

/// Paints cybernetic corner guide brackets
class _CyberCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AxisColors.primarySoft.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const cornerLen = 16.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLen), paint);

    // Top-Right
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width - cornerLen, 0), paint);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width, cornerLen), paint);

    // Bottom-Left
    canvas.drawLine(
        Offset(0, size.height), Offset(cornerLen, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - cornerLen), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - cornerLen, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - cornerLen), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
