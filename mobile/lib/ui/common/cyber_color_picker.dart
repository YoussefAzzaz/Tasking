import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

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
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(borderWidth),
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
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AxisColors.surfaceLow,
            ),
            child: const Center(
              child: Icon(
                Icons.add_rounded,
                size: 18,
                color: AxisColors.textHigh,
              ),
            ),
          ),
        ),
      );
  }
}

/// Cyberpunk-styled modern Color Picker dialog with HSV sliders,
/// Hex input, live preview, and curated vibrant palette presets.
class CyberColorPickerDialog extends StatefulWidget {
  const CyberColorPickerDialog({
    super.key,
    required this.initialColorHex,
  });

  final String initialColorHex;

  @override
  State<CyberColorPickerDialog> createState() => _CyberColorPickerDialogState();
}

class _CyberColorPickerDialogState extends State<CyberColorPickerDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hexController;

  static const List<String> _quickPresets = [
    '#6366F1', // Indigo
    '#06B6D4', // Cyan
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#EC4899', // Rose
    '#8B5CF6', // Purple
    '#EF4444', // Red
    '#14B8A6', // Teal
    '#3B82F6', // Blue
    '#F97316', // Orange
    '#84CC16', // Lime
    '#D946EF', // Fuchsia
    '#0EA5E9', // Sky
    '#E11D48', // Crimson
    '#22C55E', // Green
    '#A855F7', // Violet
  ];

  @override
  void initState() {
    super.initState();
    final initialColor = _parseColor(widget.initialColorHex);
    _hsv = HSVColor.fromColor(initialColor);
    _hexController = TextEditingController(text: _colorToHex(initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF6366F1);
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  void _onColorUpdated(HSVColor newHsv) {
    setState(() {
      _hsv = newHsv;
      _hexController.text = _colorToHex(newHsv.toColor());
    });
  }

  void _onHexChanged(String value) {
    final clean = value.replaceAll('#', '').trim();
    if (clean.length == 6) {
      try {
        final parsed = Color(int.parse('FF$clean', radix: 16));
        setState(() {
          _hsv = HSVColor.fromColor(parsed);
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _hsv.toColor();
    final currentHex = _colorToHex(activeColor);

    return AlertDialog(
      backgroundColor: AxisColors.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AxisColors.borderPrimary, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.palette_rounded, color: activeColor, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Pick Accent Color',
              style: TextStyle(
                color: AxisColors.textHigh,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live Color Preview Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.5),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECTED COLOR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AxisColors.textMuted,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentHex,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AxisColors.textHigh,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Hue Spectrum Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HUE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.textMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${_hsv.hue.round()}°',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _ColorTrackSlider(
                value: _hsv.hue / 360.0,
                onChanged: (ratio) {
                  _onColorUpdated(_hsv.withHue(ratio * 360.0));
                },
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Saturation Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SATURATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.textMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${(_hsv.saturation * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _ColorTrackSlider(
                value: _hsv.saturation,
                onChanged: (ratio) {
                  _onColorUpdated(_hsv.withSaturation(ratio));
                },
                gradient: LinearGradient(
                  colors: [
                    HSVColor.fromAHSV(1.0, _hsv.hue, 0.0, _hsv.value).toColor(),
                    HSVColor.fromAHSV(1.0, _hsv.hue, 1.0, _hsv.value).toColor(),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Brightness Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BRIGHTNESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.textMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    '${(_hsv.value * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _ColorTrackSlider(
                value: _hsv.value,
                onChanged: (ratio) {
                  _onColorUpdated(_hsv.withValue(ratio.clamp(0.05, 1.0)));
                },
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    HSVColor.fromAHSV(1.0, _hsv.hue, _hsv.saturation, 1.0).toColor(),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Hex Input
              const Text(
                'HEX CODE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AxisColors.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _hexController,
                style: const TextStyle(
                  color: AxisColors.textHigh,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: AxisColors.textDim),
                  filled: true,
                  fillColor: AxisColors.surfaceHigh,
                  hintText: '#6366F1',
                  hintStyle: const TextStyle(color: AxisColors.textDim),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AxisColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AxisColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: activeColor, width: 1.5),
                  ),
                ),
                onChanged: _onHexChanged,
              ),
              const SizedBox(height: 18),

              // Quick Vibrant Presets
              const Text(
                'POPULAR PRESETS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AxisColors.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickPresets.map((hex) {
                  final col = _parseColor(hex);
                  final isSelected = currentHex.toUpperCase() == hex.toUpperCase();
                  return InkWell(
                    onTap: () {
                      _onColorUpdated(HSVColor.fromColor(col));
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: col.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AxisColors.textDim),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: activeColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 4,
          ),
          onPressed: () {
            Navigator.pop(context, currentHex);
          },
          child: const Text(
            'Select Color',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

/// Custom lightweight drag slider for spectrum gradients.
/// Avoids Material [Slider] internal [OverlayPortal] semantics issues on desktop platforms.
class _ColorTrackSlider extends StatelessWidget {
  const _ColorTrackSlider({
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
    final clampedX = (localPosition.dx - (thumbDiameter / 2)).clamp(0.0, availableWidth);
    final ratio = clampedX / availableWidth;
    onChanged(ratio.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const thumbDiameter = 22.0;
        final availableWidth = (totalWidth - thumbDiameter).clamp(1.0, double.infinity);
        final leftOffset = (value.clamp(0.0, 1.0) * availableWidth);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _handleDrag(details.localPosition, totalWidth),
          onPanUpdate: (details) => _handleDrag(details.localPosition, totalWidth),
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
