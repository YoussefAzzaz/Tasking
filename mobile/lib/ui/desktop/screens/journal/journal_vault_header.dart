import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/note_repository.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/ghost_button.dart';

/// Top breadcrumbs and action buttons header for the Journal Vault screen.
class JournalVaultHeader extends StatelessWidget {
  final Note? selectedNote;
  final bool isCreating;
  final String activeTab;
  final String editorText;
  final VoidCallback onTogglePin;
  final VoidCallback onDeleteSelectedNote;
  final VoidCallback onExportMarkdown;
  final ValueChanged<String> onStartNewEntry;
  final VoidCallback? onShareSelectedNote;

  const JournalVaultHeader({
    super.key,
    required this.selectedNote,
    required this.isCreating,
    required this.activeTab,
    required this.editorText,
    required this.onTogglePin,
    required this.onDeleteSelectedNote,
    required this.onExportMarkdown,
    required this.onStartNewEntry,
    this.onShareSelectedNote,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;
    final note = selectedNote;
    final isEditing = note != null && !isCreating;
    final words = editorText.isNotEmpty
        ? editorText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length
        : (note != null
            ? note.bodyMd.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length
            : 0);
    final readTime = (words / 200).ceil();

    final breadcrumbPrefix = isAr
        ? (activeTab == 'journal' ? 'قاعدة المعرفة / اليوميات / ' : 'قاعدة المعرفة / الملاحظات / ')
        : (activeTab == 'journal' ? 'Knowledge Base / Journals / ' : 'Knowledge Base / Notes / ');

    final breadcrumbTail = isEditing
        ? note.title
        : (isCreating
            ? (activeTab == 'journal' ? (isAr ? 'يومية جديدة' : 'New Journal') : (isAr ? 'ملاحظة جديدة' : 'New Note'))
            : (isAr ? 'نظرة عامة' : 'Overview'));

    final titleText = isEditing
        ? note.title
        : (isCreating
            ? (activeTab == 'journal'
                ? (isAr ? 'إنشاء يومية جديدة' : 'Create Daily Journal')
                : (isAr ? 'إنشاء ملاحظة جديدة' : 'Create Note'))
            : (activeTab == 'journal'
                ? (isAr ? 'خزينة اليوميات' : 'Journal Vault')
                : (isAr ? 'الخزينة وملاحظات البنية البرمجية' : 'Vault & Architecture Notes')));

    final telemetryText = isAr
        ? '■ $words كلمة  ·  ⏱ ~$readTime د قراءة تقريباً'
        : '■ $words words  ·  ⏱ ~$readTime min read';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    breadcrumbPrefix,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      color: AxisColors.textDim,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      breadcrumbTail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AxisColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                titleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                telemetryText,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  color: AxisColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing) ...[
              if (onShareSelectedNote != null) ...[
                GhostButton(
                  label: isAr ? 'مشاركة' : 'Share',
                  icon: Icons.ios_share_rounded,
                  color: AxisColors.secondary,
                  borderColor: AxisColors.secondary.withValues(alpha: 0.35),
                  onPressed: onShareSelectedNote!,
                ),
                const SizedBox(width: 8),
              ],
              GhostButton(
                label: note.pinned
                    ? (isAr ? 'مثبت' : 'Pinned')
                    : (isAr ? 'تثبيت' : 'Pin'),
                icon: note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: note.pinned ? AxisColors.secondary : null,
                borderColor: note.pinned ? AxisColors.secondary.withValues(alpha: 0.5) : null,
                onPressed: onTogglePin,
              ),
              const SizedBox(width: 8),
              GhostButton(
                label: isAr ? 'حذف' : 'Delete',
                icon: Icons.delete_outline_rounded,
                color: AxisColors.priorityHigh,
                borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
                onPressed: onDeleteSelectedNote,
              ),
              const SizedBox(width: 8),
              GhostButton(
                label: isAr ? 'تصدير .md' : 'Export .md',
                icon: Icons.file_download_outlined,
                onPressed: onExportMarkdown,
              ),
              const SizedBox(width: 8),
            ],
            AccentButton(
              label: AppLocalizations.of(context).isArabic
                  ? (activeTab == 'journal' ? 'يومية جديدة' : 'ملاحظة جديدة')
                  : (activeTab == 'journal' ? 'New Journal' : 'New Note'),
              icon: Icons.add_rounded,
              onPressed: () => onStartNewEntry(activeTab),
            ),
          ],
        ),
      ],
    );
  }
}

