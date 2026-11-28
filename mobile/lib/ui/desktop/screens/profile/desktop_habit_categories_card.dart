import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/habit_category_repository.dart';
import '../../../common/cyber_color_picker.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/section_header.dart';

/// Card for creating and managing Habit Categories with custom palette colors.
class DesktopHabitCategoriesCard extends StatelessWidget {
  final TextEditingController newHabitCatController;
  final String selectedHabitCatColor;
  final List<String> palette;
  final ValueChanged<String> onColorSelected;
  final VoidCallback onAddHabitCategory;

  const DesktopHabitCategoriesCard({
    super.key,
    required this.newHabitCatController,
    required this.selectedHabitCatColor,
    required this.palette,
    required this.onColorSelected,
    required this.onAddHabitCategory,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isAr ? 'تصنيفات العادات' : 'Habit Categories',
            subtitle: isAr
                ? 'تنظيم الروتين اليومي في مجالات متكاملة'
                : 'Organize routines into clustered life domains',
          ),
          const SizedBox(height: 10),

          // Add category form
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AxisColors.borderSubtle, width: 1),
                  ),
                  child: TextField(
                    controller: newHabitCatController,
                    style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: isAr ? 'عنوان تصنيف عادات جديد...' : 'New habit category title...',
                      hintStyle: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Color pickers
              ...palette.take(5).map((hex) {
                final isSelected = selectedHabitCatColor == hex;
                final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => onColorSelected(hex),
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              RainbowColorPickerButton(
                selectedColor: selectedHabitCatColor,
                size: 24,
                onColorSelected: onColorSelected,
              ),
              const SizedBox(width: 8),
              AccentButton(
                label: isAr ? '+ إضافة' : '+ Add',
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: onAddHabitCategory,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category list
          StreamBuilder<List<HabitCategory>>(
            stream: HabitCategoryRepository().watchCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              if (categories.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      isAr ? 'لم يتم إنشاء تصنيفات مخصصة بعد' : 'No custom categories created yet',
                      style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    Color catColor = AxisColors.secondary;
                    try {
                      catColor = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
                    } catch (_) {}

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AxisColors.borderSubtle, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                cat.name,
                                style: AxisFonts.getFont(
                                  'Geist',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                          Tooltip(
                            message: isAr ? 'حذف التصنيف' : 'Delete category',
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              color: AxisColors.textDim,
                              onPressed: () => HabitCategoryRepository().deleteCategory(cat.id, name: cat.name),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

