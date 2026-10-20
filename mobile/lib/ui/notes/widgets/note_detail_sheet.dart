import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_repository.dart';

/// Modal bottom sheet displaying detailed note view, markdown content, mood badge and edit/delete actions
class NoteDetailSheet extends StatelessWidget {
  const NoteDetailSheet({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isJournal = note.category == 'journal';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF50C1626),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                Row(
                  children: [
                    Icon(
                      isJournal
                          ? Icons.auto_stories_rounded
                          : Icons.article_rounded,
                      color: AxisColors.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      note.category.toUpperCase(),
                      style: const TextStyle(
                        color: AxisColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AxisColors.secondary, size: 20),
                      tooltip: 'Edit Entry',
                      onPressed: () {
                        Navigator.pop(context);
                        onEdit();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AxisColors.error, size: 20),
                      tooltip: 'Delete Entry',
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AxisColors.textHigh,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, d MMM yyyy • HH:mm').format(note.createdAt),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AxisColors.textMuted),
            ),
            if (note.mood != null) ...[
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
                      note.mood!,
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
            const Divider(color: AxisColors.borderSubtle, height: 28),
            Text(
              note.bodyMd.isEmpty
                  ? 'No additional notes provided.'
                  : note.bodyMd,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AxisColors.textHigh,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onEdit();
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Entry'),
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
    );
  }
}
