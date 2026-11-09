import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

/// Section displaying all active task tags with creation and deletion capabilities
class TaskTagsSection extends StatelessWidget {
  const TaskTagsSection({
    super.key,
    required this.taskTags,
    required this.onAddTag,
    required this.onDeleteTag,
  });

  final List<String> taskTags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onDeleteTag;

  void _showAddTagDialog(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final tagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          isArabic ? 'وسم مهمة جديد' : 'New Task Tag',
          style: const TextStyle(
            color: AxisColors.textHigh,
            fontWeight: FontWeight.bold,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isArabic ? 'اسم الوسم' : 'TAG NAME',
                style: TextStyle(
                  color: AxisColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: isArabic ? 0.0 : 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: tagCtrl,
                autofocus: false,
                style: const TextStyle(color: AxisColors.textHigh),
                decoration: InputDecoration(
                  prefixText: '@',
                  prefixStyle: const TextStyle(
                    color: AxisColors.primarySoft,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: isArabic
                      ? 'مثال: عاجل، تطوير، مراجعة'
                      : 'e.g. urgent, backend, review',
                  hintStyle: const TextStyle(color: AxisColors.textDim),
                  filled: true,
                  fillColor: AxisColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AxisColors.borderSubtle),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel',
                style: const TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AxisColors.primary,
            ),
            onPressed: () {
              final tagName = tagCtrl.text.trim().replaceAll('@', '');
              Navigator.pop(ctx);
              if (tagName.isNotEmpty) {
                onAddTag(tagName);
              }
            },
            child: Text(isArabic ? 'إنشاء الوسم' : 'Create Tag',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTag(BuildContext context, String tagName) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          isArabic ? 'حذف الوسم "@$tagName"؟' : 'Delete tag "@$tagName"?',
          style: const TextStyle(color: AxisColors.textHigh),
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من رغبتك في حذف الوسم "@$tagName"؟ ستحتفظ المهام الحالية التي تحمله بسجلها.'
              : 'Are you sure you want to delete the tag "@$tagName"? Existing tasks with this tag will retain their history.',
          style: const TextStyle(color: AxisColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              onDeleteTag(tagName);
            },
            child: Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isArabic ? 'وسوم المهام' : 'TASK TAGS',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AxisColors.textMuted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: isArabic ? 0.0 : 0.8,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddTagDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AxisColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AxisColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 14, color: AxisColors.primarySoft),
                      const SizedBox(width: 4),
                      Text(
                        isArabic ? 'وسم جديد' : 'New Tag',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AxisColors.primarySoft,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (taskTags.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Center(
              child: Text(
                isArabic ? 'لم يتم العثور على وسوم مخصصة' : 'No custom tags found',
                style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: taskTags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AxisColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@$tag',
                      style: const TextStyle(
                        color: AxisColors.primarySoft,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _confirmDeleteTag(context, tag),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AxisColors.textDim,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
