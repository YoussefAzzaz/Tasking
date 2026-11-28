import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/note_repository.dart';
import 'package:intl/intl.dart';

/// Inspiring, serene Daily Journal widget for the main dashboard.
/// Features a calm, relaxing aesthetic with time-of-day contextual prompts,
/// subtle mood selector chips, streak indicator, and mini-vault entry preview.
class DailyJournalCard extends StatelessWidget {
  const DailyJournalCard({
    super.key,
    required this.todayJournal,
    required this.onOpenTodayJournal,
    required this.onStartNewJournal,
    this.onStartNewJournalWithPrompt,
    this.onAppendToTodayJournal,
    this.streak = 0,
  });

  final Note? todayJournal;
  final void Function(Note note) onOpenTodayJournal;
  final VoidCallback onStartNewJournal;
  final void Function({String? initialMood, String? initialPrompt})? onStartNewJournalWithPrompt;
  final void Function(Note note)? onAppendToTodayJournal;
  final int streak;

  void _handleStart({String? initialMood, String? initialPrompt}) {
    if (onStartNewJournalWithPrompt != null) {
      onStartNewJournalWithPrompt!(initialMood: initialMood, initialPrompt: initialPrompt);
    } else {
      onStartNewJournal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final now = DateTime.now();
    final dateStr = context.formatDate(now, 'EEEE, MMM d');
    final hasEntry = todayJournal != null;
    final hour = now.hour;

    // Contextual time-of-day intelligence
    final isMorning = hour >= 4 && hour < 12;
    final isAfternoon = hour >= 12 && hour < 18;

    final Color themeAccent = hasEntry
        ? AxisColors.tertiary
        : (isMorning
            ? const Color(0xFFF59E0B) // Amber
            : (isAfternoon
                ? const Color(0xFF0EA5E9) // Sky Blue
                : const Color(0xFF818CF8))); // Calm Indigo / Violet

    final IconData timeIcon = hasEntry
        ? Icons.auto_stories_rounded
        : (isMorning
            ? Icons.wb_twilight_rounded
            : (isAfternoon
                ? Icons.wb_sunny_rounded
                : Icons.nightlight_round));

    final String timeSubBadge = hasEntry
        ? (isArabic ? 'تم تسجيل يومية اليوم' : "TODAY'S JOURNAL LOGGED")
        : (isMorning
            ? (isArabic ? 'نية الصباح والتركيز' : 'MORNING INTENTION')
            : (isAfternoon
                ? (isArabic ? 'محطة منتصف اليوم' : 'MIDDAY CHECKPOINT')
                : (isArabic ? 'تأملات وحصاد المساء' : 'EVENING REFLECTION')));

    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top Header Row ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: themeAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: themeAccent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        timeIcon,
                        color: themeAccent,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isArabic ? 'اليوميات اليومية' : 'DAILY JOURNAL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: hasEntry ? AxisColors.textHigh : themeAccent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            timeSubBadge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: hasEntry ? AxisColors.tertiary : AxisColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Streak & Date Pill
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (streak > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AxisColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AxisColors.warning.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 12,
                              color: AxisColors.warning,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${streak}d',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AxisColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        dateStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AxisColors.textDim,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Logged State ─────────────────────────────────────────────
          if (hasEntry) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF070F1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AxisColors.tertiary.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 3.5,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AxisColors.tertiary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AutoDirectionText(
                          todayJournal!.title.isNotEmpty
                              ? todayJournal!.title
                              : (isArabic ? 'يومية اليوم' : 'Today\'s Journal'),
                          style: const TextStyle(
                            color: AxisColors.textHigh,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  AutoDirectionText(
                    todayJournal!.bodyMd.isNotEmpty
                      ? todayJournal!.bodyMd
                          .replaceAll(RegExp(r'#+\s*'), '')
                          .replaceAll(RegExp(r'\*\*|__'), '')
                          .trim()
                      : (isArabic ? 'تم تسجيل أحداث اليوم.' : 'Events recorded for today.'),
                    style: const TextStyle(
                      color: AxisColors.textMuted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Metrics footer
                  Row(
                    children: [
                      if (todayJournal!.mood != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AxisColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: AxisColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bolt_rounded, size: 11, color: AxisColors.warning),
                              const SizedBox(width: 3),
                              Text(
                                todayJournal!.mood!,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: AxisColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Word count pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 11, color: AxisColors.textDim),
                            const SizedBox(width: 3),
                            Text(
                              '${_computeWordCount(todayJournal!.bodyMd)} ${isArabic ? 'كلمة' : 'words'}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AxisColors.textDim,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Recorded time
                      Text(
                        DateFormat('hh:mm a').format(todayJournal!.createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AxisColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Action buttons bar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (onAppendToTodayJournal != null) {
                        onAppendToTodayJournal!(todayJournal!);
                      } else {
                        onOpenTodayJournal(todayJournal!);
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                    label: Text(
                      isArabic ? 'تسجيل أحداث إضافية' : 'Log More Events',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AxisColors.secondary,
                      side: BorderSide(color: AxisColors.secondary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onOpenTodayJournal(todayJournal!),
                    icon: const Icon(Icons.menu_book_rounded, size: 14),
                    label: Text(
                      isArabic ? 'عرض التدوينة' : 'View Entry',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AxisColors.surfaceHigh,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                  ),
                ),
              ],
            ),
          ]

          // ── Clean Serene Empty Prompt State ─────────────────────────────
          else ...[
            // Primary Title
            Text(
              isArabic
                  ? 'دوّن الأحداث التي وقعت خلال يومك'
                  : 'Log things that happened in your day',
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              isMorning
                  ? (isArabic
                      ? 'حدد نواياك، وأولوياتك، ورسّخ توجهك الذهني الإيجابي.'
                      : 'Set intentions, key priorities, and mindful focus.')
                  : (isAfternoon
                      ? (isArabic
                          ? 'التقط ما أنجزته وأزل أي عقبات تعترض طريقك.'
                          : 'Capture what worked, decisions made, and momentum.')
                      : (isArabic
                          ? 'سجل لحظات الامتنان وأبرز المحطات قبل النوم.'
                          : 'Acknowledge growth, express gratitude, and reflect.')),
              style: const TextStyle(color: AxisColors.textDim, fontSize: 11, height: 1.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),

            // Subtle Mood Selector Chips
            Row(
              children: [
                _buildMoodPill(
                  label: isArabic ? 'طاقة' : 'High Energy',
                  icon: Icons.bolt_rounded,
                  color: AxisColors.warning,
                  onTap: () => _handleStart(initialMood: 'HIGH ENERGY'),
                ),
                const SizedBox(width: 6),
                _buildMoodPill(
                  label: isArabic ? 'تركيز' : 'Deep Focus',
                  icon: Icons.center_focus_strong_rounded,
                  color: AxisColors.secondary,
                  onTap: () => _handleStart(initialMood: 'CALM FOCUS'),
                ),
                const SizedBox(width: 6),
                _buildMoodPill(
                  label: isArabic ? 'سكينة' : 'Calm',
                  icon: Icons.spa_rounded,
                  color: AxisColors.tertiary,
                  onTap: () => _handleStart(initialMood: 'CALM FOCUS'),
                ),
                const SizedBox(width: 6),
                _buildMoodPill(
                  label: isArabic ? 'تأمل' : 'Reflective',
                  icon: Icons.psychology_rounded,
                  color: AxisColors.primarySofter,
                  onTap: () => _handleStart(initialMood: 'REFLECTIVE'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Clean CTA Button
            InkWell(
              onTap: () => _handleStart(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeAccent.withValues(alpha: 0.9),
                      themeAccent.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isArabic ? 'بدء تدوينة يوميات اليوم' : 'Start Today\'s Journal Entry',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, size: 10, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            '+25 XP',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Root cause: arrow_forward_rounded auto-mirrors in RTL; ternary flipped twice.
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoodPill({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _computeWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}
