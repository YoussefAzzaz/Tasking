import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';

/// Modal bottom sheet to select and attach an active task to the focus timer
class AttachTaskSheet extends StatefulWidget {
  const AttachTaskSheet({
    super.key,
    required this.taskRepo,
    required this.onSelectTask,
  });

  final TaskRepository taskRepo;
  final ValueChanged<Task> onSelectTask;

  @override
  State<AttachTaskSheet> createState() => _AttachTaskSheetState();
}

class _AttachTaskSheetState extends State<AttachTaskSheet> {
  late final Stream<List<Task>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _tasksStream = widget.taskRepo.watchTasks();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xF50C1626),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AxisColors.borderGlass2,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          Text(
            isArabic ? 'ربط مهمة الهدف' : 'ATTACH TARGET TASK',
            style: const TextStyle(
              color: AxisColors.secondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _tasksStream,
              builder: (context, snapshot) {
                final tasks = (snapshot.data ?? [])
                    .where((t) => t.status != 'done')
                    .toList();

                if (tasks.isEmpty) {
                  return Center(
                    child: Text(
                      isArabic ? 'لا توجد مهام نشطة' : 'No active tasks found',
                      style: const TextStyle(color: AxisColors.textDim),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = tasks[i];
                    return Material(
                      color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          widget.onSelectTask(t);
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      t.title,
                                      style: const TextStyle(
                                        color: AxisColors.textHigh,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (t.dueDate != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        isArabic
                                            ? 'الاستحقاق: ${t.dueDate}'
                                            : 'Due: ${t.dueDate}',
                                        style: const TextStyle(
                                          color: AxisColors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isArabic
                                    ? Icons.arrow_back_ios_rounded
                                    : Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AxisColors.secondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
