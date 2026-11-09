import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/habit_category_repository.dart';
import '../../../../data/habit_repository.dart';
import '../../dialogs/quick_habit_dialog.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/section_header.dart';

/// Command deck card displaying enrolled habit loops and streaks.
class CommandDeckHabitLoopsCard extends StatefulWidget {
  const CommandDeckHabitLoopsCard({
    super.key,
    required this.onNavigateToTab,
  });

  final ValueChanged<int> onNavigateToTab;

  @override
  State<CommandDeckHabitLoopsCard> createState() => _CommandDeckHabitLoopsCardState();
}

class _CommandDeckHabitLoopsCardState extends State<CommandDeckHabitLoopsCard> {
  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isArabic ? 'التتابع وحلقات العادات' : 'STREAKS & HABIT LOOPS',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GhostButton(
                  label: isArabic ? 'جديدة' : 'New',
                  icon: Icons.add_rounded,
                  height: 26,
                  onPressed: () => QuickHabitDialog.show(
                    context,
                    onHabitCreated: () {
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 6),
                GhostButton(
                  label: isArabic ? 'عرض ↗' : 'View ↗',
                  height: 26,
                  onPressed: () => widget.onNavigateToTab(2), // Prayer & Habits (Tab 2)
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<List<HabitCategory>>(
              stream: HabitCategoryRepository().watchCategories(),
              builder: (context, catSnap) {
                final categories = catSnap.data ?? [];

                return StreamBuilder<List<Habit>>(
                  stream: HabitRepository().watchHabits(),
                  builder: (context, snapshot) {
                    final rawHabits = List<Habit>.from(
                      (snapshot.data ?? []).where((h) => h.isEnabled),
                    )..sort(HabitRepository.compareByTime);
                    final habits = rawHabits.take(4).toList();
                    if (habits.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            isArabic
                                ? 'لا توجد عادات نشطة بعد. اضغط + جديدة لإضافة عادة.'
                                : 'No active habits enrolled. Click + New to add one.',
                            style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 64,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: habits.length,
                      itemBuilder: (context, i) {
                        final h = habits[i];
                        final catColor = HabitCategoryRepository().resolveHabitCategoryColor(h, categories);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => QuickHabitDialog.show(
                              context,
                              habitToEdit: h,
                              onHabitCreated: () {
                                if (mounted) setState(() {});
                              },
                            ),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: AxisColors.surfaceLowest,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AxisColors.borderSubtle, width: 1),
                              ),
                              child: Row(
                                children: [
                                  DesktopCheckbox(
                                    value: h.isDoneToday,
                                    color: catColor,
                                    onChanged: (val) {
                                      HabitRepository().toggleHabit(h.id, val);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          h.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.getFont(
                                            'Geist',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: h.isDoneToday ? AxisColors.textDim : AxisColors.textHigh,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: catColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${isArabic ? "تتابع ${h.streakDays} أيام" : "${h.streakDays}d streak"} · ${(isArabic && h.category.toLowerCase() == "general") ? "عام" : (h.category.isNotEmpty ? h.category : (isArabic ? "عام" : "General"))}${h.remindTime != null && h.remindTime!.trim().isNotEmpty ? " · ${h.remindTime}" : ""}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.spaceGrotesk(
                                                  fontSize: 10,
                                                  color: AxisColors.textDim,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
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
