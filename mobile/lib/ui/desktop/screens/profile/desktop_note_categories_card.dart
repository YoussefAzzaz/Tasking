import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/note_category_repository.dart';
import '../../../common/cyber_color_picker.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/section_header.dart';

/// Card for creating and managing Note Categories with custom palette colors.
class DesktopNoteCategoriesCard extends StatelessWidget {
  final TextEditingController newNoteCatController;
  final String selectedNoteCatColor;
  final List<String> palette;
  final ValueChanged<String> onColorSelected;
  final VoidCallback onAddNoteCategory;

  const DesktopNoteCategoriesCard({
    super.key,
    required this.newNoteCatController,
    required this.selectedNoteCatColor,
    required this.palette,
    required this.onColorSelected,
    required this.onAddNoteCategory,
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
            title: isAr ? 'تصنيفات الملاحظات' : 'Note Categories',
            subtitle: isAr
                ? 'تصنيف الأبحاث والملاحظات الهندسية واليوميات'
                : 'Classify research, engineering notes, and journals',
          ),
          const SizedBox(height: 10),

          // Add note category form
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
                    controller: newNoteCatController,
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: isAr ? 'تصنيف ملاحظات جديد...' : 'New note category...',
                      hintStyle: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
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
                final isSelected = selectedNoteCatColor == hex;
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
                selectedColor: selectedNoteCatColor,
                size: 24,
                onColorSelected: onColorSelected,
              ),
              const SizedBox(width: 8),
              AccentButton(
                label: isAr ? '+ إضافة' : '+ Add',
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: onAddNoteCategory,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Note categories list
          StreamBuilder<List<NoteCategory>>(
            stream: NoteCategoryRepository().watchCategories(),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              if (categories.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      isAr ? 'لم يتم إنشاء تصنيفات ملاحظات مخصصة بعد' : 'No custom note categories created yet',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
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
                                style: GoogleFonts.getFont(
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
                              onPressed: () => NoteCategoryRepository().deleteCategory(cat.id, name: cat.name),
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

