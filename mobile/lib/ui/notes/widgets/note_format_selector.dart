import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Selection buttons for Note format: Standard Note vs Daily Journal
class NoteFormatSelector extends StatelessWidget {
  const NoteFormatSelector({
    super.key,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final String selectedCategory; // 'note' or 'journal'
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteSectionTitle(label: isArabic ? 'التنسيق' : 'FORMAT'),
        Row(
          children: [
            _CategoryOption(
              label: isArabic ? 'ملاحظة' : 'Note',
              icon: Icons.article_rounded,
              isSelected: selectedCategory == 'note',
              onTap: () => onSelectCategory('note'),
            ),
            const SizedBox(width: 8),
            _CategoryOption(
              label: isArabic ? 'يوميات' : 'Journal',
              icon: Icons.auto_stories_rounded,
              isSelected: selectedCategory == 'journal',
              onTap: () => onSelectCategory('journal'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Mood & Energy selector chips for journal entries
class NoteMoodSelector extends StatelessWidget {
  const NoteMoodSelector({
    super.key,
    required this.selectedMood,
    required this.onSelectMood,
  });

  final String selectedMood;
  final ValueChanged<String> onSelectMood;

  static const moods = [
    {'label': 'HIGH ENERGY', 'icon': Icons.bolt_rounded, 'color': AxisColors.warning},
    {'label': 'CALM FOCUS', 'icon': Icons.spa_rounded, 'color': AxisColors.secondary},
    {'label': 'DEEP FLOW', 'icon': Icons.psychology_rounded, 'color': AxisColors.primary},
    {'label': 'RECHARGE', 'icon': Icons.battery_charging_full_rounded, 'color': AxisColors.success},
  ];

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteSectionTitle(label: isArabic ? 'حالة الطاقة والمزاج' : 'ENERGY & MOOD STATE'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: moods.map((m) {
            final rawLabel = m['label'] as String;
            final isSel = selectedMood == rawLabel;
            final color = m['color'] as Color;
            return InkWell(
              onTap: () => onSelectMood(rawLabel),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel
                      ? color.withValues(alpha: 0.25)
                      : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? color : AxisColors.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(m['icon'] as IconData, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      l10n.localizedMood(rawLabel),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? color : AxisColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AxisColors.secondary.withValues(alpha: 0.22)
                : AxisColors.surfaceHigh.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AxisColors.secondary : AxisColors.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected ? AxisColors.secondary : AxisColors.textDim),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AxisColors.textHigh : AxisColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteSectionTitle extends StatelessWidget {
  const NoteSectionTitle({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AxisColors.textMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: isArabic ? 0.0 : 1.1,
            ),
      ),
    );
  }
}

/// Header bar for note creation and editing sheet
class NoteSheetHeader extends StatelessWidget {
  const NoteSheetHeader({
    super.key,
    required this.isEdit,
    required this.isJournal,
    required this.onClose,
  });

  final bool isEdit;
  final bool isJournal;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isEdit
        ? (isJournal
            ? (isArabic ? 'تعديل تدوينة اليوميات' : 'EDIT JOURNAL ENTRY')
            : (isArabic ? 'تعديل الملاحظة' : 'EDIT NOTE'))
        : (isJournal
            ? (isArabic ? 'تدوينة يوميات جديدة' : 'NEW JOURNAL ENTRY')
            : (isArabic ? 'ملاحظة جديدة' : 'NEW NOTE'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AxisColors.borderGlass2,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AxisColors.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: AxisColors.secondary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AxisColors.textHigh,
                          fontWeight: FontWeight.bold,
                          letterSpacing: isArabic ? 0.0 : 1.5,
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AxisColors.textMuted, size: 22),
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gradient action button for saving or updating notes and journals
class NoteSubmitButton extends StatelessWidget {
  const NoteSubmitButton({
    super.key,
    required this.isEdit,
    required this.isSaving,
    required this.onPressed,
  });

  final bool isEdit;
  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AxisColors.secondary, Color(0xFF0284C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AxisColors.secondary.withValues(alpha: 0.4),
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
                      strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bookmark_added_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isEdit
                          ? (isArabic ? 'تحديث التدوينة' : 'UPDATE ENTRY')
                          : (isArabic ? 'حفظ التدوينة' : 'SAVE ENTRY'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: isArabic ? 0.0 : 1.2,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
