import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/domain/models/habit_continuity_metrics.dart';
import 'package:axis/ui/habits/create_habit_sheet.dart';
import 'package:axis/ui/habits/widgets/habit_continuity_card.dart';
import 'package:axis/ui/habits/widgets/habits_categories_view.dart';
import 'package:axis/ui/habits/widgets/prayer_times_card.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/core/l10n/app_localizations.dart';

export 'package:axis/domain/models/habit_continuity_metrics.dart';
export 'package:axis/ui/habits/widgets/habit_continuity_card.dart';
export 'package:axis/ui/habits/widgets/habit_category_card.dart';
export 'package:axis/ui/habits/widgets/habits_categories_view.dart';
export 'package:axis/ui/habits/widgets/prayer_times_card.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _repo = HabitRepository();
  late final Stream<List<StreakLog>> _habitLogsStream;
  late final Stream<List<HabitCategory>> _habitCategoriesStream;
  late final Stream<List<Habit>> _habitsStream;
  late final Stream<List<Prayer>> _prayersStream;
  List<HabitCategory> _latestCategories = [];

  @override
  void initState() {
    super.initState();
    _habitLogsStream = _repo.watchStreakLogs();
    _habitCategoriesStream = HabitCategoryRepository().watchCategories();
    _habitsStream = _repo.watchHabits();
    _prayersStream = PrayerTimeService().watchPrayers();
  }

  void _openCreateHabit({String? initialCategory, List<HabitCategory>? existingCategories}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateHabitSheet(
        initialCategory: initialCategory,
        existingCategories: existingCategories ?? _latestCategories,
        onHabitCreated: () => setState(() {}),
      ),
    );
  }

  Future<void> _confirmResetStreak() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          context.isArabic ? 'إعادة تعيين سلسلة العادات؟' : 'Reset Habit Streak?',
          style: const TextStyle(color: AxisColors.textHigh),
        ),
        content: Text(
          context.isArabic
              ? 'سيؤدي هذا إلى إعادة تعيين سلسلة عاداتك الحالية إلى 0 يوم. سيتم الاحتفاظ بجميع العادات.'
              : 'This will reset your current habit streak to 0 days. All habit definitions will be preserved.',
          style: const TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.isArabic ? 'إلغاء' : 'Cancel',
                style: const TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              context.isArabic ? 'إعادة التعيين إلى 0' : 'Reset to 0',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.resetAllStreaks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isArabic
                ? 'تمت إعادة تعيين سلسلة العادات إلى 0 يوم'
                : 'Habit streak has been reset to 0 days',
          ),
          backgroundColor: AxisColors.surfaceLow,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // STREAK & CONTINUITY PULSE HERO
          StreamBuilder<List<StreakLog>>(
            stream: _habitLogsStream,
            builder: (context, snapshot) {
              final streakLogs = snapshot.data ?? [];
              final metrics = HabitContinuityCalculator.calculate(
                streakLogs,
                isArabic: context.isArabic,
              );

              return HabitContinuityCard(
                currentStreak: metrics.currentStreak,
                bestStreak: metrics.bestStreak,
                multiplierStr: metrics.multiplierStr,
                monthlyRate: metrics.monthlyRate,
                weekDayWidgets: metrics.weekDayWidgets,
                onResetStreak: _confirmResetStreak,
              );
            },
          ),

          const SizedBox(height: 16),

          // DEDICATED ISLAMIC PRAYERS CARD (Fixed 5 prayers from dedicated table)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<Prayer>>(
              stream: _prayersStream,
              builder: (context, prayerSnapshot) {
                final prayers = (prayerSnapshot.data != null &&
                        prayerSnapshot.data!.isNotEmpty)
                    ? prayerSnapshot.data!
                    : PrayerTimeService.defaultPrayers();
                return PrayerTimesCard(
                  prayers: prayers,
                  onTogglePrayer: (prayer, done) =>
                      PrayerTimeService().togglePrayer(prayer.id, done),
                  onResetPrayers: () =>
                      PrayerTimeService().resetPrayers(),
                  onRefreshLocation: () =>
                      PrayerTimeService().syncPrayers(forceLocation: true),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // HABIT CATEGORIES HEADER BANNER WITH "+ Add Habit" BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded,
                            color: AxisColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.habitRoutinesByCategory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AxisColors.success,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _openCreateHabit(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      backgroundColor:
                          AxisColors.success.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_rounded,
                        size: 14, color: AxisColors.success),
                    label: Text(
                      l10n.addHabit,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // DYNAMIC HABIT CATEGORY STREAM & LIST
          HabitCategoriesView(
            repo: _repo,
            habitCategoriesStream: _habitCategoriesStream,
            habitsStream: _habitsStream,
            onCategoriesUpdated: (cats) => _latestCategories = cats,
            onOpenCreateHabit: _openCreateHabit,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
