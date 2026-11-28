import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/section_header.dart';

/// Card for quickly capturing fleeting thoughts and distractions during deep work.
class DesktopDistractionsCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSave;

  const DesktopDistractionsCard({
    super.key,
    required this.controller,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isAr ? 'ملاحظات سريعة ومشتتات الذهن' : 'QUICK NOTES & DISTRACTIONS',
            subtitle: isAr
                ? 'التقط الأفكار العابرة دون قطع حبل تركيزك'
                : 'Capture fleeting thoughts without breaking flow',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: controller,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: AxisFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
              decoration: InputDecoration(
                hintText: isAr
                    ? 'التقط فكرة سريعة أو مهمة أو خاطرة لمراجعتها لاحقاً...'
                    : 'Capture a quick idea, task or thought to review later...',
                hintStyle: AxisFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              ),
              onSubmitted: (_) => onSave(),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: GhostButton(
              label: isAr ? 'حفظ الملاحظة في الخزينة' : 'Save Note to Vault',
              icon: Icons.save_outlined,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}

