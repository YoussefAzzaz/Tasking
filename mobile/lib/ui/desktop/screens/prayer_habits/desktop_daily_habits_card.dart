import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/habit_category_repository.dart';
import '../../../../data/habit_repository.dart';
import '../../../common/axis_snackbar.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Right-hand panel for habit categorization, tracking, pausing, editing, and deletion.
class DesktopDailyHabitsCard extends StatefulWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final Function([Habit?]) onShowCreateHabitDialog;

  const DesktopDailyHabitsCard({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onShowCreateHabitDialog,
  });

  @override
  State<DesktopDailyHabitsCard> createState() => _DesktopDailyHabitsCardState();
}

class _DesktopDailyHabitsCardState extends State<DesktopDailyHabitsCard> {
  final ScrollController _habitsScrollController = ScrollController();
  final Map<String, bool> _optimisticEnabled = {};
  final Map<String, bool> _optimisticDone = {};

  @override
  void dispose() {
    _habitsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isArabic ? 'العادات اليومية' : 'Daily Habits',
            trailing: AccentButton(
              label: isArabic ? 'عادة جديدة' : 'New Habit',
              height: 30,
              icon: Icons.add_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: () => widget.onShowCreateHabitDialog(),
            ),
          ),
          const SizedBox(height: 6),
          // Category tabs and Habit rows
          Expanded(
            child: StreamBuilder<List<HabitCategory>>(
              stream: HabitCategoryRepository().watchCategories(),
              builder: (context, catSnap) {
                final categories = catSnap.data ?? [];
                final categoryNames = ['All Habits', ...categories.map((c) => c.name)];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopHorizontalScrollView(
                      child: Row(
                        children: categoryNames.map((cat) {
                          final isSel = widget.selectedCategory == cat;
                          final displayCat = cat == 'All Habits'
                              ? (isArabic ? 'كل العادات' : 'All Habits')
                              : cat;
                          return Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6.0),
                            child: GestureDetector(
                              onTap: () => widget.onCategorySelected(cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSel ? AxisColors.primary.withValues(alpha: 0.25) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSel ? AxisColors.primary : AxisColors.borderSubtle,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  displayCat,
                                  style: GoogleFonts.getFont(
                                    'Geist',
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                    color: isSel ? AxisColors.textHigh : AxisColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Habit rows - scrollable filling available card height
                    Expanded(
                      child: StreamBuilder<List<Habit>>(
                        stream: HabitRepository().watchHabits(),
                        builder: (context, snapshot) {
                          final allHabits = snapshot.data ?? [];
                          for (final h in allHabits) {
                            if (_optimisticEnabled.containsKey(h.id) && _optimisticEnabled[h.id] == h.isEnabled) {
                              _optimisticEnabled.remove(h.id);
                            }
                            if (_optimisticDone.containsKey(h.id) && _optimisticDone[h.id] == h.isDoneToday) {
                              _optimisticDone.remove(h.id);
                            }
                          }
                          final habits = (widget.selectedCategory == 'All Habits'
                              ? List<Habit>.from(allHabits)
                              : allHabits.where((h) => h.category.toLowerCase() == widget.selectedCategory.toLowerCase()).toList())
                            ..sort(HabitRepository.compareByTime);

                          if (habits.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Text(
                                  isArabic
                                      ? 'لا توجد عادات في هذا التصنيف. انقر على عادة جديدة لإنشائها.'
                                      : 'No habits in this category. Click New Habit to create one.',
                                  style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                                ),
                              ),
                            );
                          }

                          return Scrollbar(
                            controller: _habitsScrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _habitsScrollController,
                              padding: const EdgeInsetsDirectional.only(end: 12.0),
                              itemCount: habits.length,
                              itemBuilder: (context, index) => _buildHabitRow(habits[index], categories),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitRow(Habit habit, [List<HabitCategory>? categories]) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final habitColor = HabitCategoryRepository().resolveHabitCategoryColor(habit, categories);
    final isEnabled = _optimisticEnabled.containsKey(habit.id)
        ? _optimisticEnabled[habit.id]!
        : habit.isEnabled;
    final isDone = _optimisticDone.containsKey(habit.id)
        ? _optimisticDone[habit.id]!
        : habit.isDoneToday;

    final scheduleLabel = habit.scheduleType.isNotEmpty
        ? (isArabic
            ? (habit.scheduleType.toLowerCase() == 'daily' ? 'يومي' : habit.scheduleType)
            : habit.scheduleType)
        : (isArabic ? 'يومي' : 'Daily');
    final categoryLabel = habit.category.isNotEmpty
        ? (isArabic && habit.category.toLowerCase() == 'general' ? 'عام' : habit.category)
        : (isArabic ? 'عام' : 'General');
    final pausedLabel = !isEnabled ? (isArabic ? '  ·  (متوقفة)' : '  ·  (Paused)') : '';

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AxisColors.borderSubtle, width: 1),
        ),
        child: Row(
          children: [
            DesktopCheckbox(
              value: isDone,
              color: isEnabled ? habitColor : AxisColors.textDim,
              onChanged: isEnabled
                  ? (val) {
                      setState(() {
                        _optimisticDone[habit.id] = val;
                      });
                      HabitRepository().toggleHabit(habit.id, val);
                    }
                  : null,
            ),
            const SizedBox(width: 10),
            Container(
              width: 3,
              height: 24,
              decoration: BoxDecoration(
                color: isEnabled ? habitColor : AxisColors.textDim,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => widget.onShowCreateHabitDialog(habit),
                borderRadius: BorderRadius.circular(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: GoogleFonts.getFont(
                        'Geist',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: habit.isDoneToday ? TextDecoration.lineThrough : null,
                        color: !isEnabled
                            ? AxisColors.textDim
                            : (habit.isDoneToday ? AxisColors.textDim : AxisColors.textHigh),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$scheduleLabel  ·  $categoryLabel$pausedLabel',
                          style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                        if (habit.remindTime != null && habit.remindTime!.trim().isNotEmpty && isEnabled) ...[
                          Text(
                            '  ·  ',
                            style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                          ),
                          const Icon(Icons.access_time_rounded, size: 11, color: AxisColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            habit.remindTime!,
                            style: GoogleFonts.getFont(
                              'Geist',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AxisColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isEnabled) ...[
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 14, color: AxisColors.warning),
                  const SizedBox(width: 2),
                  Text(
                    isArabic ? 'تتابع ${habit.streakDays} أيام' : '${habit.streakDays}d streak',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              TelemetryChip(
                label: habit.isDoneToday
                    ? (isArabic ? 'تم' : 'Done')
                    : (isArabic ? 'مجدولة' : 'Scheduled'),
                color: habit.isDoneToday ? AxisColors.tertiary : AxisColors.textDim,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              ),
            ] else ...[
              TelemetryChip(
                label: isArabic ? 'متوقفة مؤقتاً' : 'Paused',
                color: AxisColors.textDim,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              ),
            ],
            const SizedBox(width: 8),
            // Active / Pause toggle switch
            Tooltip(
              message: isEnabled
                  ? (isArabic ? 'إيقاف العادة مؤقتاً' : 'Pause habit')
                  : (isArabic ? 'تفعيل العادة' : 'Activate habit'),
              child: SizedBox(
                height: 20,
                width: 32,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: isEnabled,
                    activeThumbColor: habitColor,
                    activeTrackColor: habitColor.withValues(alpha: 0.35),
                    inactiveThumbColor: AxisColors.textDim,
                    inactiveTrackColor: AxisColors.surfaceHigh,
                    onChanged: (val) {
                      setState(() {
                        _optimisticEnabled[habit.id] = val;
                      });
                      HabitRepository().toggleHabitEnabled(habit.id, val);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.onShowCreateHabitDialog(habit),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.edit_outlined, size: 15, color: AxisColors.textDim),
                ),
              ),
            ),
            const SizedBox(width: 2),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AxisColors.canvasBase,
                      title: Text(
                        isArabic ? 'حذف العادة' : 'Delete Habit',
                        style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh),
                      ),
                      content: Text(
                        isArabic
                            ? 'هل أنت متأكد من حذف "${habit.name}"؟'
                            : 'Are you sure you want to delete "${habit.name}"?',
                        style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(
                            isArabic ? 'إلغاء' : 'Cancel',
                            style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(
                            isArabic ? 'حذف' : 'Delete',
                            style: const TextStyle(color: AxisColors.priorityHigh),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final hName = habit.name;
                    await HabitRepository().deleteHabit(habit.id);
                    if (mounted) {
                      AxisSnackBar.showDeleted(context, itemTitle: hName, itemType: 'Habit');
                    }
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.delete_outline_rounded, size: 15, color: AxisColors.textDim),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
