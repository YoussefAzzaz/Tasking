import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';

export 'package:axis/data/habit_category_repository.dart' show HabitCategory;
export 'package:axis/ui/habits/widgets/habit_category_selector_field.dart';

/// Color Accent circular dot selector row
class ColorAccentSelector extends StatelessWidget {
  const ColorAccentSelector({
    super.key,
    required this.selectedColor,
    required this.onSelectColor,
  });

  final String selectedColor;
  final ValueChanged<String> onSelectColor;

  static const colors = [
    {'hex': '#10B981', 'color': AxisColors.success, 'label': 'Emerald'},
    {'hex': '#0EA5E9', 'color': AxisColors.secondary, 'label': 'Cyan'},
    {'hex': '#6366F1', 'color': AxisColors.primary, 'label': 'Indigo'},
    {'hex': '#F59E0B', 'color': AxisColors.warning, 'label': 'Amber'},
    {'hex': '#EC4899', 'color': Color(0xFFEC4899), 'label': 'Rose'},
  ];

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return AxisColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = !colors.any(
        (c) => (c['hex'] as String).toUpperCase() == selectedColor.toUpperCase());

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...colors.map((c) {
          final isSel = selectedColor.toUpperCase() == (c['hex'] as String).toUpperCase();
          final col = c['color'] as Color;
          return InkWell(
            onTap: () => onSelectColor(c['hex'] as String),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: col,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: col.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: isSel
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: Colors.white)
                  : null,
            ),
          );
        }),
        if (isCustom) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _parseHex(selectedColor),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _parseHex(selectedColor).withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                size: 18, color: Colors.white),
          ),
        ],
        RainbowColorPickerButton(
          selectedColor: selectedColor,
          size: 34,
          borderWidth: 2.2,
          onColorSelected: onSelectColor,
        ),
      ],
    );
  }
}

/// XP Reward tier selector buttons [10, 20, 30, 50]
class XpRewardSelector extends StatelessWidget {
  const XpRewardSelector({
    super.key,
    required this.targetXp,
    required this.onSelectXp,
  });

  final int targetXp;
  final ValueChanged<int> onSelectXp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [10, 20, 30, 50].map((xp) {
        final isSel = targetXp == xp;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onSelectXp(xp),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? AxisColors.success.withValues(alpha: 0.22)
                      : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? AxisColors.success : AxisColors.borderSubtle,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    AppLocalizations.of(context).isArabic
                        ? '+$xp نقطة'
                        : '+$xp XP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSel ? AxisColors.success : AxisColors.textDim,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Header row for habit bottom sheet and dialog
class HabitSheetHeader extends StatelessWidget {
  const HabitSheetHeader({
    super.key,
    required this.isEdit,
    required this.onClose,
  });

  final bool isEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AxisColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AxisColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isEdit
                        ? (AppLocalizations.of(context).isArabic ? 'تعديل العادة' : 'EDIT HABIT ROUTINE')
                        : (AppLocalizations.of(context).isArabic ? 'عادة جديدة' : 'NEW HABIT ROUTINE'),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AxisColors.textHigh,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AxisColors.textMuted, size: 22),
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// Primary activate/update button and optional delete action for habits
class HabitActionButtons extends StatelessWidget {
  const HabitActionButtons({
    super.key,
    required this.isEdit,
    required this.isSaving,
    required this.onSave,
    this.onDelete,
  });

  final bool isEdit;
  final bool isSaving;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onSave,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AxisColors.success,
                  Color(0xFF059669),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.success.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_task_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isEdit
                              ? (AppLocalizations.of(context).isArabic ? 'تحديث العادة' : 'UPDATE HABIT')
                              : (AppLocalizations.of(context).isArabic ? 'تفعيل العادة' : 'ACTIVATE HABIT'),
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (isEdit && onDelete != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isSaving ? null : onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AxisColors.error,
              side: const BorderSide(
                color: AxisColors.error,
                width: 1.2,
              ),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(
              AppLocalizations.of(context).isArabic ? 'حذف العادة' : 'DELETE HABIT',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
