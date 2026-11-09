import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/task_repository.dart';
import '../../../today/widgets/time_slot_card.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Card showing 15-minute quick-execution macro slots scheduled for today.
class MacroSlotsCard extends StatelessWidget {
  const MacroSlotsCard({
    super.key,
    required this.onTaskPreview,
  });

  final ValueChanged<Task> onTaskPreview;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: TaskRepository().watchTasks(),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        final slottedTasks = tasks.where((t) {
          final isToday = t.dueDate != null &&
              (t.dueDate == todayStr || t.dueDate!.startsWith(todayStr));
          if (!isToday) return false;
          final estimate = t.estimateMin;
          return estimate != null && estimate <= 15;
        }).toList();
        final isArabic = AppLocalizations.of(context).isArabic;

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isArabic ? 'الفترات المصغرة 15 د' : '15 MIN MACRO SLOTS',
                trailing: TelemetryChip(
                  label: isArabic ? '${slottedTasks.length} فترات' : '${slottedTasks.length} SLOTS',
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 6),
              // AI insight banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.psychology_rounded,
                      color: AxisColors.secondary,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        slottedTasks.isNotEmpty
                            ? (isArabic
                                ? 'تمت جدولة ${slottedTasks.length} مهام مصغرة (≤15د).'
                                : '${slottedTasks.length} macro-task${slottedTasks.length > 1 ? 's' : ''} (≤15m) slotted.')
                            : (isArabic
                                ? 'المجدول التلقائي نشط (≤15د).'
                                : 'Auto-scheduler active (≤15m).'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textHigh),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic
                                  ? 'أعاد المجدول التلقائي احتساب الفترات المتاحة!'
                                  : 'Auto-Scheduler recalculated idle gaps!',
                            ),
                            backgroundColor: AxisColors.secondary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        isArabic ? 'إعادة الجدولة' : 'RESCHEDULE',
                        style: GoogleFonts.getFont(
                          'Geist',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: slottedTasks.isEmpty
                    ? SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_empty_rounded, color: AxisColors.secondary, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isArabic
                                          ? 'لا توجد فترات 15 دقيقة مجدولة'
                                          : 'No 15-Minute Slots Scheduled',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: AxisColors.textHigh,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isArabic
                                          ? 'تظهر هنا مهام اليوم التي يستغرق إنجازها 15 دقيقة أو أقل.'
                                          : 'Today\'s tasks with estimates of 15 minutes or less appear here.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.getFont('Geist', color: AxisColors.textDim, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: slottedTasks.length,
                        itemBuilder: (context, i) {
                          final t = slottedTasks[i];
                          final isDone = t.isCompleted;
                          final timeStr = t.dueTime != null && t.dueTime!.isNotEmpty
                              ? t.dueTime!
                              : '${t.estimateMin ?? 15}M Macro';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: TimeSlotCard(
                              time: timeStr,
                              title: t.title,
                              xp: t.priority == 1 ? 30 : 20,
                              isDone: isDone,
                              onToggle: (v) {
                                TaskRepository().toggleTaskStatus(t, v);
                              },
                              onTap: () => onTaskPreview(t),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
