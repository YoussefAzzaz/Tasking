import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/models/task_filter_criteria.dart';
import 'package:axis/ui/tasks/tasks_empty_state.dart';
import 'widgets/outdated_filter_bar.dart';
import 'widgets/outdated_section.dart';

export 'widgets/outdated_filter_bar.dart';
export 'widgets/outdated_section.dart';

/// OUTDATED & FINISHED TAB
/// Displays past-due (outdated) tasks and completed (finished) tasks
/// with real-time PowerSync reactive updates, Filter Studio criteria support,
/// and interactive filter pills.
class OutdatedTab extends StatefulWidget {
  const OutdatedTab({
    super.key,
    required this.repo,
    required this.filterCriteria,
  });

  final TaskRepository repo;
  final ValueNotifier<TaskFilterCriteria> filterCriteria;

  @override
  State<OutdatedTab> createState() => _OutdatedTabState();
}

class _OutdatedTabState extends State<OutdatedTab> {
  late final Stream<List<Task>> _tasksStream;
  OutdatedFilterMode _activeFilter = OutdatedFilterMode.all;

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

            final tasks = snapshot.data ?? [];
            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

            final outdated = <Task>[];
            final finished = <Task>[];

            for (final t in tasks) {
              if (!criteria.matches(t)) continue;

              if (t.status == 'done') {
                finished.add(t);
              } else if (t.dueDate != null &&
                  t.dueDate!.trim().isNotEmpty &&
                  t.dueDate!.compareTo(todayStr) < 0) {
                outdated.add(t);
              }
            }

            // Sort outdated chronologically: oldest overdue first
            outdated.sort(compareTasksByDueDate);

            // Sort finished: most recently scheduled/due first
            finished.sort((a, b) {
              final aDue = a.dueDate;
              final bDue = b.dueDate;
              if (aDue != null && bDue != null) {
                final cmp = bDue.compareTo(aDue);
                if (cmp != 0) return cmp;
              }
              if (aDue != null && bDue == null) return -1;
              if (aDue == null && bDue != null) return 1;
              return a.title.toLowerCase().compareTo(b.title.toLowerCase());
            });

            final totalCount = outdated.length + finished.length;

            if (totalCount == 0) {
              if (criteria.isActive) {
                return TasksEmptyState(
                  isFiltered: true,
                  onReset: () =>
                      widget.filterCriteria.value = const TaskFilterCriteria(),
                );
              }
              return OutdatedEmptyStateCard(
                icon: Icons.task_alt_rounded,
                accentColor: AxisColors.primary,
                title: context.isArabic ? 'لا توجد مهام فائتة أو مكتملة' : 'No Outdated or Finished Tasks',
                subtitle: context.isArabic
                    ? 'جميع المهام النشطة في موعدها، ولم يتم تسجيل مهام مكتملة بعد.'
                    : 'All active tasks are on schedule, and no completed tasks have been recorded yet.',
              );
            }

            final showOutdated = _activeFilter == OutdatedFilterMode.all ||
                _activeFilter == OutdatedFilterMode.outdated;
            final showFinished = _activeFilter == OutdatedFilterMode.all ||
                _activeFilter == OutdatedFilterMode.finished;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Top filter pill selectors (All | Outdated | Finished)
                OutdatedFilterPills(
                  allCount: totalCount,
                  outdatedCount: outdated.length,
                  finishedCount: finished.length,
                  activeFilter: _activeFilter,
                  onFilterChanged: (filter) =>
                      setState(() => _activeFilter = filter),
                ),
                const SizedBox(height: 12),

                // Outdated / Overdue section
                if (showOutdated && outdated.isNotEmpty)
                  OutdatedSection(
                    title: context.isArabic ? 'فائتة' : 'OUTDATED',
                    subtitle: context.isArabic
                        ? 'تجاوزت تاريخ الاستحقاق • مجمعة حسب التاريخ • انقر على مربع الاختيار للإكمال'
                        : 'Past due date • grouped by date • tap checkbox to mark complete',
                    color: AxisColors.error,
                    tasks: outdated,
                    repo: widget.repo,
                    groupByDate: true,
                  ),

                if (showOutdated &&
                    outdated.isEmpty &&
                    _activeFilter == OutdatedFilterMode.outdated)
                  OutdatedEmptyStateCard(
                    icon: Icons.done_all_rounded,
                    accentColor: AxisColors.tertiary,
                    title: context.isArabic ? 'لا توجد مهام فائتة' : 'No Outdated Tasks',
                    subtitle: context.isArabic
                        ? 'عمل رائع! جميع مهامك النشطة محدثة وضمن مواعيدها النهائية.'
                        : 'Great job! All your active tasks are up to date and within their deadlines.',
                  ),

                // Finished / Completed section
                if (showFinished && finished.isNotEmpty) ...[
                  if (showOutdated && outdated.isNotEmpty)
                    const SizedBox(height: 10),
                  OutdatedSection(
                    title: context.isArabic ? 'مكتملة' : 'FINISHED',
                    subtitle: context.isArabic
                        ? 'مهام مكتملة • انقر على مربع الاختيار للإعادة'
                        : 'Completed tasks • tap checkbox to restore to todo',
                    color: AxisColors.tertiary,
                    tasks: finished,
                    repo: widget.repo,
                  ),
                ],

                if (showFinished &&
                    finished.isEmpty &&
                    _activeFilter == OutdatedFilterMode.finished)
                  OutdatedEmptyStateCard(
                    icon: Icons.fact_check_outlined,
                    accentColor: AxisColors.secondary,
                    title: context.isArabic ? 'لا توجد مهام مكتملة' : 'No Finished Tasks',
                    subtitle: context.isArabic
                        ? 'ستظهر المهام المكتملة هنا كسجل لإنجازاتك.'
                        : 'Completed tasks will appear here as a record of your achievements.',
                  ),

                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }
}
