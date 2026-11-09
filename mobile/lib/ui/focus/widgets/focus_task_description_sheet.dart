import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/reading_preferences_service.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/reading_font_size_control.dart';

/// Modal bottom sheet displaying detailed markdown notes and reading controls for an attached task.
class FocusTaskDescriptionSheet extends StatefulWidget {
  final Task initialTask;
  final ValueChanged<Task> onTaskUpdated;
  final VoidCallback onSwitchTask;

  const FocusTaskDescriptionSheet({
    super.key,
    required this.initialTask,
    required this.onTaskUpdated,
    required this.onSwitchTask,
  });

  static void show({
    required BuildContext context,
    required Task task,
    required ValueChanged<Task> onTaskUpdated,
    required VoidCallback onSwitchTask,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FocusTaskDescriptionSheet(
        initialTask: task,
        onTaskUpdated: onTaskUpdated,
        onSwitchTask: onSwitchTask,
      ),
    );
  }

  @override
  State<FocusTaskDescriptionSheet> createState() => _FocusTaskDescriptionSheetState();
}

class _FocusTaskDescriptionSheetState extends State<FocusTaskDescriptionSheet> {
  late Task _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.initialTask;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF50C1626),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modal Drag Handle
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

          // Header: Icon + Title + Close Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AxisColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AxisColors.secondary.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  color: AxisColors.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.isArabic
                          ? 'الهدف المحدد'
                          : 'TARGET OBJECTIVE',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.textMuted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _currentTask.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.textHigh,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.isArabic ? 'إغلاق الوصف' : 'Close description',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AxisColors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AxisColors.borderSubtle, height: 1),
          const SizedBox(height: 14),

          // Description Body (Markdown rendered)
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.isArabic
                            ? 'الوصف / الملاحظات'
                            : 'DESCRIPTION / NOTES',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.secondary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (_currentTask.notes != null &&
                          _currentTask.notes!.trim().isNotEmpty)
                        const ReadingFontSizeControl(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_currentTask.notes != null &&
                      _currentTask.notes!.trim().isNotEmpty)
                    ValueListenableBuilder<double>(
                      valueListenable: ReadingPreferencesService().fontScaleNotifier,
                      builder: (context, fontScale, _) {
                        return AxisMarkdownViewer(
                          markdown: _currentTask.notes!,
                          selectable: true,
                          fontScale: fontScale,
                          onMarkdownChanged: (updatedNotes) async {
                            final updatedTask = _currentTask.copyWith(notes: updatedNotes);
                            setState(() => _currentTask = updatedTask);
                            widget.onTaskUpdated(updatedTask);
                            await TaskRepository().updateTask(updatedTask);
                          },
                        );
                      },
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLow.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notes_rounded,
                              size: 16, color: AxisColors.textDim),
                          const SizedBox(width: 8),
                          Text(
                            context.isArabic
                                ? 'لا يوجد وصف مضاف لهذه المهمة.'
                                : 'No description provided for this task.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AxisColors.textDim,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AxisColors.textHigh,
                    side: const BorderSide(color: AxisColors.borderSubtle),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSwitchTask();
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: Text(
                    context.isArabic ? 'تبديل المهمة' : 'Switch Task',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AxisColors.secondary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    context.isArabic ? 'العودة إلى التركيز' : 'Back to Focus',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

