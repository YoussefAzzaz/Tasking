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
    final tagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text(
          'New Task Tag',
          style: TextStyle(
            color: AxisColors.textHigh,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TAG NAME',
              style: TextStyle(
                color: AxisColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: tagCtrl,
              autofocus: true,
              style: const TextStyle(color: AxisColors.textHigh),
              decoration: InputDecoration(
                prefixText: '@',
                prefixStyle: const TextStyle(
                  color: AxisColors.primarySoft,
                  fontWeight: FontWeight.bold,
                ),
                hintText: 'e.g. urgent, backend, review',
                hintStyle: const TextStyle(color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AxisColors.textDim)),
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
            child: const Text('Create Tag',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TASK TAGS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AxisColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            InkWell(
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: AxisColors.primarySoft),
                    SizedBox(width: 4),
                    Text(
                      'New Tag',
                      style: TextStyle(
                        fontSize: 11,
                        color: AxisColors.primarySoft,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
            child: const Center(
              child: Text(
                'No custom tags found',
                style: TextStyle(color: AxisColors.textDim, fontSize: 12),
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
                    InkWell(
                      onTap: () => onDeleteTag(tag),
                      borderRadius: BorderRadius.circular(10),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AxisColors.textDim,
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
