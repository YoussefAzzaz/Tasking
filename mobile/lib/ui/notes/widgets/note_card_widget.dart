import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/note_repository.dart';

/// Card preview for note or journal entry with icon, title, snippet, time and mood
class NoteCardWidget extends StatelessWidget {
  const NoteCardWidget({super.key, required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final isJournal = note.category == 'journal';
    final icon =
        isJournal ? Icons.auto_stories_rounded : Icons.article_rounded;
    final dateStr = context.formatDate(note.createdAt, 'h:mm a • MMM d');
    final cleanSender = (note.senderUsername ?? '')
        .trim()
        .replaceFirst(RegExp(r'^@+'), '')
        .trim();

    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isJournal
                  ? AxisColors.secondary.withValues(alpha: 0.15)
                  : AxisColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                color: isJournal ? AxisColors.secondary : AxisColors.primary,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: AutoDirectionText(
                        note.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.w600,
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (note.pinned)
                      const Icon(Icons.push_pin_rounded,
                          size: 14, color: AxisColors.warning),
                  ],
                ),
                const SizedBox(height: 4),
                if (note.bodyMd.isNotEmpty)
                  AutoDirectionText(
                    note.bodyMd
                        .replaceAll(RegExp(r'#+\s*'), '')
                        .replaceAll('**', '')
                        .replaceAll('*', '')
                        .replaceAll(RegExp(r'>\s*'), '')
                        .trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AxisColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 11, color: AxisColors.textDim),
                    ),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cleanSender.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsetsDirectional.only(end: 6),
                              decoration: BoxDecoration(
                                color: AxisColors.primarySoft
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '@$cleanSender',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AxisColors.primarySoft,
                                ),
                              ),
                            ),
                          if (note.category.isNotEmpty &&
                              note.category != 'note' &&
                              note.category != 'journal' &&
                              note.category.toLowerCase() != 'general notes') ...[
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                margin: const EdgeInsetsDirectional.only(end: 6),
                                decoration: BoxDecoration(
                                  color:
                                      AxisColors.secondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AxisColors.secondary
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  context.l10n.localizedNoteCategory(note.category),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AxisColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (note.mood != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AxisColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                note.mood!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AxisColors.warning,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
