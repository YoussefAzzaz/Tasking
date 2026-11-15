import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/reading_preferences_service.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/reading_font_size_control.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';

/// Modal bottom sheet displaying detailed note view, markdown content, mood badge and edit/delete actions
class NoteDetailSheet extends StatefulWidget {
  const NoteDetailSheet({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    this.onNoteUpdated,
  });

  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Note>? onNoteUpdated;

  @override
  State<NoteDetailSheet> createState() => _NoteDetailSheetState();
}

class _NoteDetailSheetState extends State<NoteDetailSheet> {
  late Note _note;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  @override
  void didUpdateWidget(covariant NoteDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note != oldWidget.note) {
      _note = widget.note;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final isJournal = _note.category == 'journal';
    final cleanSender = (_note.senderUsername ?? '')
        .trim()
        .replaceFirst(RegExp(r'^@+'), '')
        .trim();

    return ModalSheetScaffold(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xF50C1626),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Top handle and category bar (tap to close automatically)
              ModalSheetTopBar(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AxisColors.borderGlass2,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isJournal
                                    ? Icons.auto_stories_rounded
                                    : Icons.article_rounded,
                                color: AxisColors.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  l10n
                                      .localizedNoteCategory(_note.category)
                                      .toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AxisColors.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: isArabic ? 0.0 : 1.2,
                                  ),
                                ),
                              ),
                              if (cleanSender.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AxisColors.primarySoft
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '@$cleanSender',
                                    style: const TextStyle(
                                      color: AxisColors.primarySoft,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.ios_share_rounded,
                                  color: AxisColors.primarySoft, size: 20),
                              tooltip: isArabic
                                  ? 'مشاركة مع صاحب'
                                  : 'Share with Companion',
                              onPressed: () =>
                                  ShareTaskSheet.showForNote(context, _note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: AxisColors.secondary, size: 20),
                              tooltip: isArabic ? 'تعديل التدوينة' : 'Edit Entry',
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onEdit();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AxisColors.error, size: 20),
                              tooltip: isArabic ? 'حذف التدوينة' : 'Delete Entry',
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onDelete();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            AutoDirectionText(
              _note.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AxisColors.textHigh,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              context.formatDate(_note.createdAt, 'EEEE, d MMM yyyy • HH:mm'),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AxisColors.textMuted),
            ),
            if (_note.mood != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AxisColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                      size: 14, color: AxisColors.warning),
                    const SizedBox(width: 4),
                    Text(
                      l10n.localizedMood(_note.mood!),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isJournal
                      ? (isArabic ? 'تدوينة اليوميات' : 'JOURNAL ENTRY')
                      : (isArabic ? 'محتوى الملاحظة' : 'NOTE CONTENT'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AxisColors.textDim,
                    letterSpacing: isArabic ? 0.0 : 1.2,
                  ),
                ),
                const ReadingFontSizeControl(),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AxisColors.borderSubtle, height: 1),
            const SizedBox(height: 10),

            // Scrollable Note Markdown Content
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable:
                          ReadingPreferencesService().fontScaleNotifier,
                      builder: (context, fontScale, _) {
                        return AxisMarkdownViewer(
                          markdown: _note.bodyMd,
                          fontScale: fontScale,
                          onMarkdownChanged: (updatedBody) async {
                            final updated = _note.copyWith(bodyMd: updatedBody);
                            setState(() => _note = updated);
                            await NoteRepository().updateNote(updated);
                            widget.onNoteUpdated?.call(updated);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onEdit();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(isArabic ? 'تعديل التدوينة' : 'Edit Entry'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AxisColors.secondary,
                          side: const BorderSide(color: AxisColors.secondary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
