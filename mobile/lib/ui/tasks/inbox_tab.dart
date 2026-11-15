import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/friends/widgets/pending_shares_section.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';
import 'package:axis/ui/tasks/tasks_empty_state.dart';
import 'package:axis/ui/tasks/upcoming_tab.dart';

/// INBOX TAB (With reactive filter criteria, due date sorting, and cached stream)
class InboxTab extends StatefulWidget {
  const InboxTab({
    super.key,
    required this.repo,
    required this.filterCriteria,
  });

  final TaskRepository repo;
  final ValueNotifier<TaskFilterCriteria> filterCriteria;

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  late final Stream<List<Task>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _tasksStream = widget.repo.watchTasks();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TaskFilterCriteria>(
      valueListenable: widget.filterCriteria,
      builder: (context, criteria, _) {
        return StreamBuilder<List<Task>>(
          stream: _tasksStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AxisColors.primary),
              );
            }

            final allTasks = snapshot.data ?? [];
            final now = DateTime.now();
            final todayStr = DateFormat('yyyy-MM-dd').format(now);

            final collaborativeTasks = allTasks.where((t) {
              if (!t.isCollaborative || !criteria.matches(t)) return false;
              if (!t.isCompleted) return true;
              return t.dueDate != null &&
                  (t.dueDate == todayStr || t.dueDate!.startsWith(todayStr));
            }).toList()
              ..sort(compareTasksByDueDate);

            // Personal normal tasks (due today or active unscheduled tasks)
            final personalTodayTasks = allTasks.where((t) {
              if (t.isCollaborative) return false;
              if (!criteria.matches(t)) return false;
              final d = t.dueDate?.trim() ?? '';
              if (d.isEmpty) {
                return !t.isCompleted;
              }
              return d == todayStr || d.startsWith(todayStr);
            }).toList()
              ..sort(compareTasksByDueDate);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: CollaborativeTaskDeletedNoticeBanner(),
                ),
                Expanded(
                  child: (collaborativeTasks.isEmpty &&
                          personalTodayTasks.isEmpty)
                      ? TasksEmptyState(
                          isFiltered: criteria.isActive,
                          onReset: () => widget.filterCriteria.value =
                              const TaskFilterCriteria(),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          children: [
                            if (collaborativeTasks.isNotEmpty)
                              UpcomingSection(
                                title: context.isArabic
                                    ? 'المهام التعاونية'
                                    : 'COLLABORATIVE TASKS',
                                color: AxisColors.secondary,
                                tasks: collaborativeTasks,
                                repo: widget.repo,
                              ),
                            if (personalTodayTasks.isNotEmpty) ...[
                              if (collaborativeTasks.isNotEmpty)
                                UpcomingSection(
                                  title: context.isArabic
                                      ? 'مهامي اليوم'
                                      : 'MY TODAY',
                                  color: AxisColors.primary,
                                  tasks: personalTodayTasks,
                                  repo: widget.repo,
                                )
                              else
                                UpcomingSection(
                                  title: context.isArabic ? 'اليوم' : 'TODAY',
                                  color: AxisColors.primary,
                                  tasks: personalTodayTasks,
                                  repo: widget.repo,
                                ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
