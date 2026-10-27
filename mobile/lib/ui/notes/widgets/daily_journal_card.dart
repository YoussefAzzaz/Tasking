import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/note_repository.dart';

/// Inspiring and functional Daily Journal card for logging events, reflections, and thoughts of the day.
class DailyJournalCard extends StatelessWidget {
  const DailyJournalCard({
    super.key,
    required this.todayJournal,
    required this.onOpenTodayJournal,
    required this.onStartNewJournal,
  });

  final Note? todayJournal;
  final void Function(Note note) onOpenTodayJournal;
  final VoidCallback onStartNewJournal;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final hasEntry = todayJournal != null;

    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with date & status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: hasEntry
                            ? AxisColors.success.withValues(alpha: 0.18)
                            : AxisColors.secondary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasEntry ? Icons.auto_stories_rounded : Icons.edit_calendar_rounded,
                        color: hasEntry ? AxisColors.success : AxisColors.secondary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasEntry ? "TODAY'S JOURNAL LOGGED" : 'DAILY JOURNAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: hasEntry ? AxisColors.success : AxisColors.secondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  dateStr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AxisColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasEntry) ...[
            // Existing journal summary
            AutoDirectionText(
              todayJournal!.title,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            AutoDirectionText(
              todayJournal!.bodyMd.isNotEmpty
                  ? todayJournal!.bodyMd.replaceAll(RegExp(r'#+\s*'), '').trim()
                  : 'Events recorded for today.',
              style: const TextStyle(
                color: AxisColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (todayJournal!.mood != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AxisColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AxisColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 12, color: AxisColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          todayJournal!.mood!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.warning,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox.shrink(),
                OutlinedButton.icon(
                  onPressed: () => onOpenTodayJournal(todayJournal!),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                  label: const Text('Log More Events', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AxisColors.secondary,
                    side: const BorderSide(color: AxisColors.secondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Prompt to start today's journal
            const Text(
              'Log things that happened in your day',
              style: TextStyle(
                color: AxisColors.textHigh,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Capture timeline milestones, key wins, blockers, and reflections.',
              style: TextStyle(color: AxisColors.textDim, fontSize: 11),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onStartNewJournal,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AxisColors.secondary, Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.secondary.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.edit_note_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Start Today\'s Journal Entry',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
