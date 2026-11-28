import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/note_repository.dart';

/// Mini weekly streak calendar for the journal vault.
class JournalDeckStreakCalendar extends StatelessWidget {
  const JournalDeckStreakCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;

    return StreamBuilder<List<Note>>(
      stream: NoteRepository().watchNotes(),
      builder: (context, snapshot) {
        final notes = snapshot.data ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final noteDates = notes.map((n) => DateFormat('yyyy-MM-dd').format(n.createdAt.toLocal())).toSet();

        int streak = 0;
        DateTime checkDay = noteDates.contains(todayStr) ? now : now.subtract(const Duration(days: 1));
        while (noteDates.contains(DateFormat('yyyy-MM-dd').format(checkDay))) {
          streak++;
          checkDay = checkDay.subtract(const Duration(days: 1));
        }

        // Week starts from Sunday:
        final sunday = now.subtract(Duration(days: now.weekday % 7));

        final streakLabel = isAr
            ? (streak > 0 ? 'تتابع $streak أيام' : 'تتابع 0 يوم')
            : (streak > 0 ? '${streak}d Streak' : '0d Streak');

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AxisColors.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAr ? 'سجل اليوميات' : 'JOURNAL DECK',
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AxisColors.textMuted,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 12, color: AxisColors.warning),
                      const SizedBox(width: 2),
                      Text(
                        streakLabel,
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: streak > 0 ? AxisColors.warning : AxisColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final day = sunday.add(Duration(days: i));
                  final dStr = DateFormat('yyyy-MM-dd').format(day);
                  final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
                  final hasNote = noteDates.contains(dStr);

                  return Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AxisColors.secondary
                          : (hasNote ? AxisColors.secondary.withValues(alpha: 0.25) : AxisColors.secondary.withValues(alpha: 0.08)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday
                            ? AxisColors.secondary
                            : (hasNote ? AxisColors.secondary : Colors.transparent),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: isToday || hasNote ? FontWeight.w700 : FontWeight.w500,
                          color: isToday
                              ? AxisColors.canvasBase
                              : (hasNote ? AxisColors.secondary : AxisColors.textDim),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

