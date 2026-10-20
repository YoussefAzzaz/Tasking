import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';

/// Modal bottom sheet to select and attach an active task to the focus timer
class AttachTaskSheet extends StatelessWidget {
  const AttachTaskSheet({
    super.key,
    required this.taskRepo,
    required this.onSelectTask,
  });

  final TaskRepository taskRepo;
  final ValueChanged<Task> onSelectTask;

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'ATTACH TARGET TASK',
            style: TextStyle(
              color: AxisColors.secondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: taskRepo.watchTasks(),
              builder: (context, snapshot) {
                final tasks = (snapshot.data ?? [])
                    .where((t) => t.status != 'done')
                    .toList();

                if (tasks.isEmpty) {
                  return const Center(
                    child: Text(
                      'No active tasks found',
                      style: TextStyle(color: AxisColors.textDim),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final t = tasks[i];
                    return ListTile(
                      tileColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: Text(
                        t.title,
                        style: const TextStyle(color: AxisColors.textHigh),
                      ),
                      subtitle: t.dueDate != null
                          ? Text(
                              'Due: ${t.dueDate}',
                              style: const TextStyle(
                                color: AxisColors.textMuted,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AxisColors.secondary,
                      ),
                      onTap: () {
                        onSelectTask(t);
                        Navigator.pop(context);
                      },
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
