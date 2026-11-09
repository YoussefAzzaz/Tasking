import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/ui/common/category_filter_slider.dart';
import 'package:axis/ui/notes/widgets/note_card_widget.dart';

/// EXPANDABLE NOTE CATEGORY CARD
/// Displays notes grouped by category with live count, expand/collapse animation,
/// quick "+ Add Note" action, and category deletion.
class NoteCategoryCard extends StatefulWidget {
  const NoteCategoryCard({
    super.key,
    required this.category,
    required this.color,
    required this.notes,
    required this.onTapNote,
    required this.onAddNote,
    this.onDeleteCategory,
    this.forceExpand = false,
  });

  final NoteCategory category;
  final Color color;
  final List<Note> notes;
  final void Function(Note note) onTapNote;
  final VoidCallback onAddNote;
  final VoidCallback? onDeleteCategory;
  final bool forceExpand;

  @override
  State<NoteCategoryCard> createState() => _NoteCategoryCardState();
}

class _NoteCategoryCardState extends State<NoteCategoryCard> {
  bool _expanded = true;

  @override
  void didUpdateWidget(covariant NoteCategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceExpand && !_expanded) {
      _expanded = true;
    }
  }

  void _confirmDeleteCategory(BuildContext context) {
    final catName = context.l10n.localizedNoteCategory(widget.category.name);
    final isArabic = context.isArabic;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          isArabic ? 'حذف "$catName"؟' : 'Delete "${widget.category.name}"?',
          style: const TextStyle(color: AxisColors.textHigh),
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من حذف فئة "$catName"؟ ستبقى الملاحظات بأمان ضمن الملاحظات العامة.'
              : 'Are you sure you want to delete the "${widget.category.name}" category? Notes in this category will remain safe in General Notes.',
          style: const TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: AxisColors.textDim),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              widget.onDeleteCategory?.call();
            },
            child: Text(
              isArabic ? 'حذف' : 'Delete',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUnassigned = widget.category.id == 'general_notes' ||
        widget.category.name.toLowerCase() == 'general notes';
    final iconData = CategorySliderItem.resolveIcon(widget.category.icon, Icons.article_rounded);
    final count = widget.notes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? widget.color.withValues(alpha: 0.3)
              : AxisColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: Radius.circular(_expanded ? 0 : 16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Category Icon Capsule
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(iconData, size: 18, color: widget.color),
                    ),
                    const SizedBox(width: 10),

                    // Category Name & Notes Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  context.l10n.localizedNoteCategory(widget.category.name),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.textHigh,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: widget.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: widget.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.isArabic
                                ? (count == 1 ? 'تدوينة واحدة' : '$count تدوينات')
                                : (count == 1 ? '1 entry' : '$count entries'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AxisColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick "+ Add Note" Action
                    IconButton(
                      icon: Icon(Icons.add_rounded, size: 18, color: widget.color),
                      tooltip: context.isArabic
                          ? 'إضافة ملاحظة إلى ${context.l10n.localizedNoteCategory(widget.category.name)}'
                          : 'Add note to ${widget.category.name}',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onAddNote,
                    ),

                    // Delete Category Action (if custom category)
                    if (!isUnassigned && widget.onDeleteCategory != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AxisColors.textDim),
                        tooltip: context.isArabic ? 'حذف الفئة' : 'Delete category',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _confirmDeleteCategory(context),
                      ),

                    // Expand/Collapse Chevron
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AxisColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsible Notes List
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(color: AxisColors.borderSubtle, height: 1),
                        const SizedBox(height: 10),
                        if (widget.notes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                context.isArabic
                                    ? 'لا توجد ملاحظات في ${context.l10n.localizedNoteCategory(widget.category.name)} بعد'
                                    : 'No notes in ${widget.category.name} yet',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AxisColors.textDim,
                                ),
                              ),
                            ),
                          )
                        else
                          ...widget.notes.map((note) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                onTap: () => widget.onTapNote(note),
                                borderRadius: BorderRadius.circular(12),
                                child: NoteCardWidget(note: note),
                              ),
                            );
                          }),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
