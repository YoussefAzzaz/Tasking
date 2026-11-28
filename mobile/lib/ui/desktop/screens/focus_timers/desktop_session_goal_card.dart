import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/focus_session_service.dart';
import '../../../../data/task_repository.dart';
import '../../../common/axis_markdown_viewer.dart';
import '../../core/task_checklist_mixin.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Card displaying the currently attached task goal, markdown description, and subtask checklist.
class DesktopSessionGoalCard extends StatelessWidget with TaskChecklistMixin {
  final VoidCallback onShowTaskSelection;

  const DesktopSessionGoalCard({
    super.key,
    required this.onShowTaskSelection,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;

    return ValueListenableBuilder<Task?>(
      valueListenable: FocusSessionService().attachedTaskNotifier,
      builder: (context, task, _) {
        final checklist = parseTaskChecklist(task?.notes);
        final cleanNotes = stripChecklistFromNotes(task?.notes);

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isAr ? 'هدف الجلسة الحالية' : 'CURRENT SESSION GOAL',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GhostButton(
                      label: task != null
                          ? (isAr ? 'تبديل المهمة' : 'Switch Task')
                          : (isAr ? 'ربط مهمة' : 'Attach Task'),
                      icon: task != null ? Icons.swap_horiz_rounded : Icons.link_rounded,
                      height: 28,
                      onPressed: onShowTaskSelection,
                    ),
                    if (task != null) ...[
                      const SizedBox(width: 8),
                      GhostButton(
                        label: isAr ? 'إلغاء ربط المهمة' : 'Detach Task',
                        icon: Icons.link_off_rounded,
                        height: 28,
                        color: AxisColors.priorityHigh,
                        borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
                        onPressed: () => FocusSessionService().setAttachedTask(null),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task != null) ...[
                      // Task Title & Priority Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PriorityBadge(priority: task.priority),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Metadata Telemetry Chips Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (task.dueDate != null && task.dueDate!.isNotEmpty)
                            TelemetryChip(
                              label: task.dueDate!,
                              color: AxisColors.secondary,
                              icon: Icons.calendar_today_rounded,
                            ),
                          if (task.estimateMin != null)
                            TelemetryChip(
                              label: isAr
                                  ? 'تقدير: ${task.estimateMin} د'
                                  : '${task.estimateMin}m Estimate',
                              color: AxisColors.primary,
                              icon: Icons.timer_outlined,
                            ),
                          TelemetryChip(
                            label: task.isCompleted
                                ? (isAr ? 'مكتملة' : 'COMPLETED')
                                : (isAr ? 'قيد التنفيذ' : 'IN PROGRESS'),
                            color: task.isCompleted ? AxisColors.tertiary : AxisColors.warning,
                          ),
                          if (checklist.isNotEmpty)
                            TelemetryChip(
                              label: isAr
                                  ? 'المهام الفرعية (${checklist.where((c) => c.isDone).length}/${checklist.length})'
                                  : 'SUBTASKS (${checklist.where((c) => c.isDone).length}/${checklist.length})',
                              color: AxisColors.secondary,
                              icon: Icons.checklist_rounded,
                            ),
                        ],
                      ),

                      // Formatted Markdown Notes
                      if (cleanNotes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: AxisColors.borderSubtle, height: 1),
                        const SizedBox(height: 10),
                        AxisMarkdownViewer(
                          markdown: cleanNotes,
                          selectable: true,
                          baseStyle: AxisFonts.getFont('Geist', fontSize: 13, height: 1.45, color: AxisColors.textHigh),
                        ),
                      ],

                      // Subtask Checklist items
                      if (checklist.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: AxisColors.borderSubtle, height: 1),
                        const SizedBox(height: 10),
                        ...checklist.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                DesktopCheckbox(
                                  value: item.isDone,
                                  size: 18,
                                  color: AxisColors.secondary,
                                  onChanged: (_) => toggleTaskChecklist(task, item.lineIndex),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.text,
                                    style: AxisFonts.getFont(
                                      'Geist',
                                      fontSize: 13,
                                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                                      color: item.isDone ? AxisColors.textDim : AxisColors.textHigh,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // Fallback when task has no notes and no checklist
                      if (cleanNotes.isEmpty && checklist.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          isAr
                              ? 'تجنب المقاطعات وحافظ على تركيز مستمر لإنجاز هذه المهمة.'
                              : 'Eliminate interruptions and maintain uninterrupted concentration on this deliverable.',
                          style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                        ),
                      ],
                    ] else ...[
                      // Standby state (no task attached)
                      Text(
                        isAr ? 'تركيز ذهني عميق وانسيابية' : 'Deep Cognitive Focus & Flow',
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr
                            ? 'تجنب المقاطعات وحافظ على تركيز مستمر دون انقطاع.'
                            : 'Eliminate interruptions and maintain uninterrupted concentration.',
                        style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

