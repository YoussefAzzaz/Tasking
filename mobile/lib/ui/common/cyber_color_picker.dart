import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'color_picker/color_presets_wrap.dart';
import 'color_picker/color_track_slider.dart';

export 'color_picker/color_presets_wrap.dart';
export 'color_picker/color_track_slider.dart';
export 'color_picker/rainbow_color_picker_button.dart';

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
    '#6366F1', // Indigo (Logo inner)
    '#0EA5E9', // Cyan (Logo inner)
    '#10B981', // Emerald
    '#F59E0B', // Amber (Logo peak)
    '#EC4899', // Rose
    '#8B5CF6', // Purple
    '#EF4444', // Red
    '#14B8A6', // Teal
    '#3B82F6', // Blue
    '#F97316', // Orange
    '#84CC16', // Lime
    '#D946EF', // Fuchsia
    '#7DD3FC', // Light Cyan (Logo outer)
    '#818CF8', // Soft Indigo (Logo outer)
    '#22C55E', // Green
    '#FCD34D', // Bright Amber (Logo peak light)
  ];

  @override
  void initState() {
    super.initState();
    final initialColor = parseHexColor(widget.initialColorHex);
    _hsv = HSVColor.fromColor(initialColor);
    _hexController = TextEditingController(text: _colorToHex(initialColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
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
    final isAr = AppLocalizations.of(context).isArabic;
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
          Expanded(
            child: Text(
              isAr ? 'اختر لون التمييز' : 'Pick Accent Color',
              style: const TextStyle(
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
              ColorPreviewBanner(
                activeColor: activeColor,
                currentHex: currentHex,
              ),
              const SizedBox(height: 18),

              // Hue Spectrum Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAr ? 'درجة اللون' : 'HUE',
                    style: const TextStyle(
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
              ColorTrackSlider(
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
                  Text(
                    isAr ? 'التشبع' : 'SATURATION',
                    style: const TextStyle(
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
              ColorTrackSlider(
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
                  Text(
                    isAr ? 'السطوع' : 'BRIGHTNESS',
                    style: const TextStyle(
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
              ColorTrackSlider(
                value: _hsv.value,
                onChanged: (ratio) {
                  _onColorUpdated(_hsv.withValue(ratio.clamp(0.05, 1.0)));
                },
                gradient: LinearGradient(
                  colors: [
                    Colors.black,
                    HSVColor.fromAHSV(1.0, _hsv.hue, _hsv.saturation, 1.0)
                        .toColor(),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Hex Input
              Text(
                isAr ? 'رمز اللون HEX' : 'HEX CODE',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AxisColors.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _hexController,
                  style: const TextStyle(
                    color: AxisColors.textHigh,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.tag_rounded,
                        size: 18, color: AxisColors.textDim),
                    filled: true,
                    fillColor: AxisColors.surfaceHigh,
                    hintText: '#6366F1',
                    hintStyle: const TextStyle(color: AxisColors.textDim),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              ),
              const SizedBox(height: 18),

              // Quick Vibrant Presets
              ColorPresetsWrap(
                presets: _quickPresets,
                currentHex: currentHex,
                onColorSelected: (col) =>
                    _onColorUpdated(HSVColor.fromColor(col)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            isAr ? 'إلغاء' : 'Cancel',
            style: const TextStyle(color: AxisColors.textDim),
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
          child: Text(
            isAr ? 'اختيار اللون' : 'Select Color',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
