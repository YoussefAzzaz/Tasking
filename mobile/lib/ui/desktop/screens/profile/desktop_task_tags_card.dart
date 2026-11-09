import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/tag_repository.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/section_header.dart';

/// Desktop card for managing task tags and taxonomy.
class DesktopTaskTagsCard extends StatelessWidget {
  final TextEditingController newTagController;
  final VoidCallback onAddTag;

  const DesktopTaskTagsCard({
    super.key,
    required this.newTagController,
    required this.onAddTag,
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
            title: isAr ? 'وسوم وعلامات المهام' : 'Task Tags & Labels',
            subtitle: isAr
                ? 'تصنيف الوسوم الشامل المطبق على كافة المهام'
                : 'Global tagging taxonomy applied across deliverables',
          ),
          const SizedBox(height: 10),

          // Add tag form
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
                    controller: newTagController,
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: isAr ? '#وسم-جديد...' : '#NEW-IDENTIFIER...',
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
              AccentButton(
                label: isAr ? '+ إنشاء وسم' : '+ Create Tag',
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: onAddTag,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tags chips flow
          StreamBuilder<List<String>>(
            stream: TagRepository().watchTags(),
            builder: (context, snapshot) {
              final tags = snapshot.data ?? [];
              if (tags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      isAr ? 'لا توجد وسوم معرفة. أضف وسماً أعلاه.' : 'No tags defined. Add one above.',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AxisColors.borderSubtle, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#$t',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AxisColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: isAr ? 'حذف الوسم' : 'Delete tag',
                          child: GestureDetector(
                            onTap: () => TagRepository().deleteTag(t),
                            child: const Icon(Icons.close_rounded, size: 13, color: AxisColors.textDim),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

