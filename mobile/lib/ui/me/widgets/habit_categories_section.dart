import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Section managing custom habit categories with add and delete capabilities
class HabitCategoriesSection extends StatelessWidget {
  const HabitCategoriesSection({
    super.key,
    required this.categories,
    required this.onAddCategory,
    required this.onDeleteCategory,
  });

  final List<Map<String, dynamic>> categories;
  final void Function(String name, String color) onAddCategory;
  final void Function(String id, String name) onDeleteCategory;

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.primary;
    try {
      final clean = hex.replaceAll('#', '').replaceAll('0x', '').trim();
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
      return AxisColors.primary;
    } catch (_) {
      return AxisColors.primary;
    }
  }

  void _showAddCategoryDialog(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final catCtrl = TextEditingController();
    String selectedColor = '#10B981';

    // Root cause: local TextEditingController outlived showDialog without disposal;
    // dispose in whenComplete after route exit completes.
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AxisColors.surfaceLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AxisColors.borderPrimary),
          ),
          title: Text(
            isArabic ? 'فئة عادات جديدة' : 'New Habit Category',
            style: const TextStyle(
              color: AxisColors.textHigh,
              fontWeight: FontWeight.bold,
            ),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          actionsOverflowButtonSpacing: 8,
          actionsOverflowDirection: VerticalDirection.down,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'اسم الفئة' : 'CATEGORY NAME',
                  style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: isArabic ? 0.0 : 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: catCtrl,
                  autofocus: false,
                  style: const TextStyle(color: AxisColors.textHigh),
                  decoration: InputDecoration(
                    hintText: isArabic
                        ? 'مثال: لياقة بدنية، تأمل، دراسة'
                        : 'e.g. Fitness, Meditation, Study',
                    hintStyle: const TextStyle(color: AxisColors.textDim),
                    filled: true,
                    fillColor: AxisColors.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AxisColors.borderSubtle),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isArabic ? 'لون التمييز' : 'COLOR ACCENT',
                  style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: isArabic ? 0.0 : 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    const presetList = AxisColors.presetHexes;
                    final isCustom = !presetList.any(
                        (p) => p.toUpperCase() == selectedColor.toUpperCase());

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ...presetList.map((hex) {
                          final col = _parseHex(hex);
                          final isSel =
                              selectedColor.toUpperCase() == hex.toUpperCase();
                          return InkWell(
                            onTap: () => setDlgState(() => selectedColor = hex),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      isSel ? Colors.white : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: isSel
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                          );
                        }),
                        if (isCustom)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _parseHex(selectedColor),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(Icons.check,
                                size: 16, color: Colors.white),
                          ),
                        RainbowColorPickerButton(
                          selectedColor: selectedColor,
                          size: 28,
                          borderWidth: 2.0,
                          onColorSelected: (newHex) {
                            setDlgState(() => selectedColor = newHex);
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'إلغاء' : 'Cancel',
                  style: const TextStyle(color: AxisColors.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AxisColors.success,
              ),
              onPressed: () {
                final catName = catCtrl.text.trim();
                Navigator.pop(ctx);
                if (catName.isNotEmpty) {
                  onAddCategory(catName, selectedColor);
                }
              },
              child: Text(isArabic ? 'إنشاء الفئة' : 'Create Category',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    ).whenComplete(catCtrl.dispose);
  }

  void _confirmDeleteCategory(BuildContext context, String id, String name) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          isArabic ? 'حذف "$name"؟' : 'Delete "$name"?',
          style: const TextStyle(color: AxisColors.textHigh),
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من رغبتك في حذف فئة العادات "$name"؟ ستُنقل العادات التابعة لها إلى الفئة العامة.'
              : 'Are you sure you want to delete the "$name" habit category? Habits in this category will move to General Routines.',
          style: const TextStyle(color: AxisColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              onDeleteCategory(id, name);
            },
            child: Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isArabic ? 'فئات العادات' : 'HABIT CATEGORIES',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AxisColors.textMuted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: isArabic ? 0.0 : 0.8,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddCategoryDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AxisColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AxisColors.success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 14, color: AxisColors.success),
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? 'فئة جديدة' : 'New Category',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AxisColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Center(
              child: Text(
                isArabic ? 'لا توجد فئات مخصصة بعد' : 'No custom categories created yet',
                style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
              ),
            ),
          )
        else
          AxisCard(
            tier: GlassTier.two,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < categories.length; i++) ...[
                  if (i > 0)
                    const Divider(color: AxisColors.borderSubtle, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _parseHex(categories[i]['color'] as String?),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _parseHex(categories[i]['color'] as String?)
                                    .withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.localizedHabitCategory((categories[i]['name'] as String?) ?? 'Category'),
                            style: const TextStyle(
                              color: AxisColors.textHigh,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AxisColors.textDim),
                          tooltip: isArabic ? 'حذف الفئة' : 'Delete Category',
                          onPressed: () => _confirmDeleteCategory(
                            context,
                            (categories[i]['id'] as String?) ?? '',
                            (categories[i]['name'] as String?) ?? 'Category',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
