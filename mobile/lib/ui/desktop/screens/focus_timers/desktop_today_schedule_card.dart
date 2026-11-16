import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/focus_repository.dart';
import '../../../../data/focus_session_service.dart';
import '../../../../data/task_repository.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Card showing today's logged focus sprints, active sprint, or scheduled upcoming tasks.
class DesktopTodayScheduleCard extends StatelessWidget {
  const DesktopTodayScheduleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FocusRepository().watchTodayFocusSessions(),
      builder: (context, sessionSnap) {
        final sessions = sessionSnap.data ?? [];

        return ValueListenableBuilder<bool>(
          valueListenable: FocusSessionService().isRunningNotifier,
          builder: (context, isRunning, _) {
            final activeTask = FocusSessionService().attachedTask;
            final remainingSec = FocusSessionService().remainingSecondsNotifier.value;
            final remainingMin = (remainingSec / 60).ceil();

            return DesktopCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: isAr ? 'جدول اليوم وجلسات التركيز' : "TODAY'S SCHEDULE & SPRINTS",
                    trailing: TelemetryChip(
                      label: isAr ? 'تم تسجيل ${sessions.length} اليوم' : '${sessions.length} logged today',
                      color: sessions.isNotEmpty ? AxisColors.tertiary : AxisColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // If active session is running, show it at the top
                  if (isRunning) ...[
                    _buildScheduleRow(
                      activeTask?.title ?? (isAr ? 'جلسة تركيز نشطة' : 'Active Focus Sprint'),
                      isAr ? 'الآن · متبقي $remainingMin د' : 'Now · $remainingMin min remaining',
                      isAr ? 'جلسة نشطة' : 'Active Sprint',
                      AxisColors.secondary,
                    ),
                  ],

                  // Completed sessions from database
                  ...sessions.map((s) {
                    final rawStart = s['started_at'] as String?;
                    final startDt = rawStart != null ? DateTime.tryParse(rawStart) : null;
                    final timeLabel = startDt != null
                        ? DateFormat('HH:mm').format(startDt.toLocal())
                        : (isAr ? 'جلسة' : 'Sprint');
                    final actualMin = (s['actual_min'] as num?)?.toInt() ?? 25;
                    final taskTitle = (s['task_title'] as String?)?.trim();
                    final title = (taskTitle != null && taskTitle.isNotEmpty)
                        ? taskTitle
                        : (isAr ? 'جلسة تركيز عميق' : 'Deep Focus Sprint');

                    return _buildScheduleRow(
                      title,
                      isAr ? '$timeLabel · $actualMin د' : '$timeLabel · ${actualMin}m',
                      isAr ? 'مكتملة' : 'Completed',
                      AxisColors.tertiary,
                    );
                  }),

                  // If no active session and no completed sessions, show scheduled tasks or prompt
                  if (!isRunning && sessions.isEmpty) ...[
                    StreamBuilder<List<Task>>(
                      stream: TaskRepository().watchTasks(),
                      builder: (context, taskSnap) {
                        final tasks = taskSnap.data ?? [];
                        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                        final todayTasks = tasks
                            .where((t) => !t.isCompleted && t.dueDate == todayStr)
                            .take(3)
                            .toList();

                        if (todayTasks.isNotEmpty) {
                          return Column(
                            children: todayTasks.map((t) {
                              return _buildScheduleRow(
                                t.title,
                                t.dueTime ?? (isAr ? 'اليوم' : 'Today'),
                                isAr ? 'مجدولة' : 'Scheduled',
                                AxisColors.textDim,
                              );
                            }).toList(),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text(
                              isAr
                                  ? 'لم تسجل أي جلسات تركيز اليوم بعد. ابدأ جلسة للانطلاق في العمل العميق.'
                                  : 'No focus sprints recorded yet today. Launch a session to begin deep work.',
                              style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleRow(String title, String timeRange, String status, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AxisColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: AxisColors.textHigh),
                  ),
                ),
                if (timeRange.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    timeRange,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          TelemetryChip(
            label: status,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          ),
        ],
      ),
    );
  }
}

