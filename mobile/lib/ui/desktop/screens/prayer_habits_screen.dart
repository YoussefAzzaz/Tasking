import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/habit_repository.dart';
import '../core/desktop_layout.dart';
import '../dialogs/quick_habit_dialog.dart';
import '../widgets/desktop_live_clock.dart';
import 'prayer_habits/desktop_prayer_settings_dialog.dart';
import 'prayer_habits/prayer_habits_stats_row.dart';
import 'prayer_habits/desktop_daily_prayers_card.dart';
import 'prayer_habits/desktop_daily_habits_card.dart';

export 'prayer_habits/desktop_prayer_settings_dialog.dart';
export 'prayer_habits/prayer_habits_stats_row.dart';
export 'prayer_habits/weekly_consistency_grid.dart';
export 'prayer_habits/desktop_daily_prayers_card.dart';
export 'prayer_habits/desktop_daily_habits_card.dart';

/// Prayer & Habits Telemetry Screen (Tab 1).
class PrayerHabitsScreen extends StatefulWidget {
  const PrayerHabitsScreen({super.key});

  @override
  State<PrayerHabitsScreen> createState() => _PrayerHabitsScreenState();
}

class _PrayerHabitsScreenState extends State<PrayerHabitsScreen> {
  String _selectedCategory = 'All Habits';

  void _showPrayerSettingsDialog() {
    DesktopPrayerSettingsDialog.show(
      context,
      onSettingsUpdated: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _showCreateHabitDialog([Habit? habitToEdit]) {
    QuickHabitDialog.show(
      context,
      initialCategory: _selectedCategory == 'All Habits' ? null : _selectedCategory,
      habitToEdit: habitToEdit,
      onHabitCreated: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
          padding: const EdgeInsets.all(DesktopLayout.panelPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3.2 Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context).isArabic ? 'الصلوات والعادات' : 'Prayer & Habits',
                          style: AxisFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AxisColors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context).isArabic
                              ? 'متابعة مواقيت الصلوات اليومية وتناسق العادات الشخصية'
                              : 'Track daily prayer times and personal habit consistency',
                          style: AxisFonts.getFont(
                            'Geist',
                            fontSize: 13,
                            color: AxisColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  DesktopLiveClock(
                    builder: (context, now) {
                      return Text(
                        DateFormat('HH:mm:ss').format(now),
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textHigh,
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: DesktopLayout.sectionSpacing),

              // 3.3 Top 4 Stats Row
              const PrayerHabitsStatsRow(),

              const SizedBox(height: DesktopLayout.sectionSpacing),

              // Main 2-Column Split: Both cards stretch to same height matching page
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: DesktopDailyPrayersCard(
                        onShowSettings: _showPrayerSettingsDialog,
                      ),
                    ),
                    const SizedBox(width: DesktopLayout.sectionSpacing),
                    Expanded(
                      flex: 5,
                      child: DesktopDailyHabitsCard(
                        selectedCategory: _selectedCategory,
                        onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
                        onShowCreateHabitDialog: _showCreateHabitDialog,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (!constraints.hasBoundedHeight || constraints.maxHeight < 640) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SizedBox(
              height: 640,
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }
}
