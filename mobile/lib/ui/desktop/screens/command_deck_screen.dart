import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/note_repository.dart';
import '../../../data/task_repository.dart';
import '../../notes/create_note_sheet.dart';
import '../../notes/widgets/daily_journal_card.dart';
import '../core/desktop_layout.dart';
import 'command_deck/command_deck_habit_loops_card.dart';
import 'command_deck/command_deck_level_xp_card.dart';
import 'command_deck/command_deck_prayer_telemetry_card.dart';
import 'command_deck/command_deck_stats_row.dart';
import 'command_deck/command_deck_welcome_header.dart';
import 'command_deck/desktop_task_preview_dialog.dart';
import 'command_deck/execution_stream_card.dart';
import 'command_deck/macro_slots_card.dart';

export 'command_deck/command_deck_habit_loops_card.dart';
export 'command_deck/command_deck_level_xp_card.dart';
export 'command_deck/command_deck_prayer_telemetry_card.dart';
export 'command_deck/command_deck_stats_row.dart';
export 'command_deck/command_deck_welcome_header.dart';
export 'command_deck/desktop_task_preview_dialog.dart';
export 'command_deck/execution_stream_card.dart';
export 'command_deck/macro_slots_card.dart';

/// Command Deck Dashboard (Tab 0) - Primary desktop mission control view.
class CommandDeckScreen extends StatefulWidget {
  const CommandDeckScreen({
    super.key,
    required this.onNavigateToTab,
    this.onOpenNewTaskDialog,
  });

  final ValueChanged<int> onNavigateToTab;
  final VoidCallback? onOpenNewTaskDialog;

  @override
  State<CommandDeckScreen> createState() => _CommandDeckScreenState();
}

class _CommandDeckScreenState extends State<CommandDeckScreen> {
  void _showTaskPreviewDialog(Task task) {
    DesktopTaskPreviewDialog.show(
      context,
      initialTask: task,
      onTaskUpdated: (_) {
        if (mounted) setState(() {});
      },
    );
  }

  void _openJournalDialog({Note? noteToEdit}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 740),
            decoration: BoxDecoration(
              color: AxisColors.canvasBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderGlass2, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CreateNoteSheet(
                initialCategory: 'journal',
                noteToEdit: noteToEdit,
                onNoteCreated: () {
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyJournalCard() {
    final now = DateTime.now();
    return StreamBuilder<List<Note>>(
      stream: NoteRepository().watchNotes(),
      builder: (context, noteSnapshot) {
        final notes = noteSnapshot.data ?? [];
        final todayJournal = notes.cast<Note?>().firstWhere(
          (n) =>
              n != null &&
              n.category == 'journal' &&
              n.createdAt.year == now.year &&
              n.createdAt.month == now.month &&
              n.createdAt.day == now.day,
          orElse: () => null,
        );

        return DailyJournalCard(
          todayJournal: todayJournal,
          onOpenTodayJournal: (note) => _openJournalDialog(noteToEdit: note),
          onStartNewJournal: () => _openJournalDialog(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2.2 Welcome Header
          const CommandDeckWelcomeHeader(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 2.3 Top Stats Row (4 cards)
          const CommandDeckStatsRow(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 2-Column Main Deck Split (Left flex 6, Right flex 4)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Expanded(
                        child: ExecutionStreamCard(
                          onTaskPreview: _showTaskPreviewDialog,
                        ),
                      ),
                      const SizedBox(height: DesktopLayout.sectionSpacing),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: MacroSlotsCard(
                                onTaskPreview: _showTaskPreviewDialog,
                              ),
                            ),
                            const SizedBox(width: DesktopLayout.sectionSpacing),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildDailyJournalCard(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DesktopLayout.sectionSpacing),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      const Expanded(
                        child: CommandDeckPrayerTelemetryCard(),
                      ),
                      const SizedBox(height: DesktopLayout.sectionSpacing),
                      Expanded(
                        child: CommandDeckHabitLoopsCard(
                          onNavigateToTab: widget.onNavigateToTab,
                        ),
                      ),
                      const SizedBox(height: DesktopLayout.sectionSpacing),
                      const CommandDeckLevelXpCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
