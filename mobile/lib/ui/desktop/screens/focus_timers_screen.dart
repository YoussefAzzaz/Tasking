import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/focus_session_service.dart';
import '../../../data/note_repository.dart';
import '../../../domain/id_generator.dart';
import '../core/desktop_layout.dart';
import '../widgets/ghost_button.dart';
import '../widgets/telemetry_chip.dart';
import 'focus_timers/desktop_focus_protocol_dialog.dart';
import 'focus_timers/desktop_timer_hero_card.dart';
import 'focus_timers/desktop_session_goal_card.dart';
import 'focus_timers/desktop_soundscapes_card.dart';
import 'focus_timers/desktop_today_schedule_card.dart';
import 'focus_timers/desktop_distractions_card.dart';
import 'focus_timers/desktop_task_selection_dialog.dart';

export 'focus_timers/desktop_focus_protocol_dialog.dart';
export 'focus_timers/desktop_timer_hero_card.dart';
export 'focus_timers/desktop_session_goal_card.dart';
export 'focus_timers/desktop_soundscapes_card.dart';
export 'focus_timers/desktop_today_schedule_card.dart';
export 'focus_timers/desktop_distractions_card.dart';
export 'focus_timers/desktop_task_selection_dialog.dart';

/// Focus Timers Screen (Tab 3) — Deep work sessions and cognitive flow control.
class FocusTimersScreen extends StatefulWidget {
  const FocusTimersScreen({super.key});

  @override
  State<FocusTimersScreen> createState() => _FocusTimersScreenState();
}

class _FocusTimersScreenState extends State<FocusTimersScreen> {
  final _distractionNoteController = TextEditingController();

  @override
  void dispose() {
    _distractionNoteController.dispose();
    super.dispose();
  }

  void _showFocusSettingsDialog() {
    DesktopFocusProtocolDialog.show(
      context,
      onConfigSaved: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _handleSaveDistractionNote() async {
    final text = _distractionNoteController.text.trim();
    if (text.isEmpty) return;

    final isAr = AppLocalizations.of(context).isArabic;
    final note = Note(
      id: IdGenerator.generateDeterministicId('note_${DateTime.now().microsecondsSinceEpoch}'),
      title: isAr ? 'فكرة مشتتة' : 'Distraction Thought',
      bodyMd: text,
      category: 'General',
    );
    await NoteRepository().addNote(note);
    _distractionNoteController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'تم حفظ الفكرة المشتتة في الخزينة' : 'Distraction captured to Vault'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 5.2 Header
          _buildHeader(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // Main Layout: Pomodoro widget takes full page width and length, and rest of widgets are organized under it
          const DesktopTimerHeroCard(isExpanded: true),
          const SizedBox(height: DesktopLayout.sectionSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    DesktopSessionGoalCard(
                      onShowTaskSelection: () => showDesktopTaskSelectionDialog(context),
                    ),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    DesktopDistractionsCard(
                      controller: _distractionNoteController,
                      onSave: _handleSaveDistractionNote,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              const Expanded(
                child: Column(
                  children: [
                    DesktopSoundscapesCard(),
                    SizedBox(height: DesktopLayout.sectionSpacing),
                    DesktopTodayScheduleCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isAr = AppLocalizations.of(context).isArabic;
    return ValueListenableBuilder<bool>(
      valueListenable: FocusSessionService().isRunningNotifier,
      builder: (context, isRunning, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: FocusSessionService().isBreakNotifier,
          builder: (context, isBreak, _) {
            final sprintLabel = isBreak
                ? (isAr ? 'استراحة استعادة النشاط' : 'REBOOT BREAK')
                : (isAr ? 'جلسة تركيز عميق' : 'FOCUS SPRINT');
            final statusLabel = isBreak
                ? (isRunning
                    ? (isAr ? 'الاستراحة قيد التقدم' : 'BREAK IN PROGRESS')
                    : (isAr ? 'استراحة في وضع الاستعداد' : 'BREAK STANDBY'))
                : (isRunning
                    ? (isAr ? 'جلسة نشطة' : 'ACTIVE SPRINT')
                    : (isAr ? 'في وضع الاستعداد' : 'STANDBY'));
            final badgeColor = isBreak ? AxisColors.warning : (isRunning ? AxisColors.tertiary : AxisColors.warning);

            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          sprintLabel,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: isBreak ? AxisColors.warning : AxisColors.secondary,
                          ),
                        ),
                        TelemetryChip(
                          label: statusLabel,
                          dotColor: badgeColor,
                          color: badgeColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isBreak
                          ? (isAr ? 'إعادة ضبط التركيز والترطيب' : 'Cognitive Reset & Hydration')
                          : (isAr ? 'جلسة تركيز للعمل العميق' : 'Deep Work Focus Session'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AxisColors.textHigh,
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<int>(
                  valueListenable: FocusSessionService().completedCyclesNotifier,
                  builder: (context, cycles, _) {
                    final sessionNum = (cycles % 4) + 1;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TelemetryChip(
                          label: isAr ? 'الجلسة: $sessionNum من 4' : 'SESSION: $sessionNum of 4',
                          color: isBreak ? AxisColors.warning : AxisColors.secondary,
                        ),
                        TelemetryChip(
                          label: isBreak
                              ? (isAr ? 'المدة: 5د استراحة' : 'DURATION: 5m Break')
                              : (isAr ? 'المدة: 25د تركيز' : 'DURATION: 25m Sprint'),
                          color: AxisColors.primarySoft,
                        ),
                        GhostButton(
                          label: isAr ? 'الإعدادات' : 'Settings',
                          icon: Icons.tune_rounded,
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: _showFocusSettingsDialog,
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
