import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/note_repository.dart';
import 'package:intl/intl.dart';

/// Inspiring, redesigned Daily Journal widget for the main menu.
/// Features dynamic time-of-day contextual prompts, quick mood selector,
/// starter prompt chips, streak indicator, and mini-vault entry preview.
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
        ? AxisColors.success
        : (isMorning
            ? const Color(0xFFF59E0B) // Amber
            : (isAfternoon
                ? AxisColors.secondary // Electric Cyan
                : const Color(0xFF818CF8))); // Soft Indigo / Violet

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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient decorative watermark
          Positioned(
            top: -10,
            right: isArabic ? null : -10,
            left: isArabic ? -10 : null,
            child: Icon(
              Icons.menu_book_rounded,
              size: 100,
              color: themeAccent.withValues(alpha: 0.035),
            ),
          ),

          Column(
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
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: themeAccent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: themeAccent.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            timeIcon,
                            color: themeAccent,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isArabic ? 'اليوميات اليومية' : 'DAILY JOURNAL',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
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
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: hasEntry ? AxisColors.success : AxisColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Streak & Date Pill (Safe on compact widths)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (streak > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AxisColors.warning.withValues(alpha: 0.28),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  size: 11,
                                  color: AxisColors.warning,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${streak}d',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AxisColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            dateStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
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

              const SizedBox(height: 8),

              // ── Logged State ─────────────────────────────────────────────
              if (hasEntry) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070F1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AxisColors.success.withValues(alpha: 0.25),
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
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AxisColors.success,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                      const SizedBox(height: 4),
                      AutoDirectionText(
                        todayJournal!.bodyMd.isNotEmpty
                          ? todayJournal!.bodyMd
                              .replaceAll(RegExp(r'#+\s*'), '')
                              .replaceAll(RegExp(r'\*\*|__'), '')
                              .trim()
                          : (isArabic ? 'تم تسجيل أحداث اليوم.' : 'Events recorded for today.'),
                        style: const TextStyle(
                          color: AxisColors.textMuted,
                          fontSize: 11,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Metrics footer
                      Row(
                        children: [
                          if (todayJournal!.mood != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AxisColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: AxisColors.warning.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 10, color: AxisColors.warning),
                                  const SizedBox(width: 2),
                                  Text(
                                    todayJournal!.mood!,
                                    style: const TextStyle(
                                      fontSize: 9,
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_note_rounded, size: 10, color: AxisColors.textDim),
                                const SizedBox(width: 2),
                                Text(
                                  '${_computeWordCount(todayJournal!.bodyMd)} ${isArabic ? 'كلمة' : 'words'}',
                                  style: const TextStyle(
                                    fontSize: 9,
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
                              fontSize: 9.5,
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
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 13),
                        label: Text(
                          isArabic ? 'تسجيل أحداث إضافية' : 'Log More Events',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: AxisColors.secondary,
                          side: BorderSide(color: AxisColors.secondary.withValues(alpha: 0.6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onOpenTodayJournal(todayJournal!),
                        icon: const Icon(Icons.menu_book_rounded, size: 13),
                        label: Text(
                          isArabic ? 'عرض التدوينة' : 'View Entry',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AxisColors.surfaceHigh,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ]

              // ── Empty Prompt State ─────────────────────────────────────────
              else ...[
                // Primary Title
                Text(
                  isArabic
                      ? 'دوّن الأحداث التي وقعت خلال يومك'
                      : 'Log things that happened in your day',
                  style: const TextStyle(
                    color: AxisColors.textHigh,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
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
                  style: const TextStyle(color: AxisColors.textDim, fontSize: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 7),

                // Quick Mood Selector Chips
                Row(
                  children: [
                    _buildMoodPill(
                      label: isArabic ? 'طاقة' : 'High Energy',
                      icon: Icons.bolt_rounded,
                      color: AxisColors.warning,
                      onTap: () => _handleStart(initialMood: 'HIGH ENERGY'),
                    ),
                    const SizedBox(width: 5),
                    _buildMoodPill(
                      label: isArabic ? 'تركيز' : 'Deep Focus',
                      icon: Icons.center_focus_strong_rounded,
                      color: AxisColors.secondary,
                      onTap: () => _handleStart(initialMood: 'CALM FOCUS'),
                    ),
                    const SizedBox(width: 5),
                    _buildMoodPill(
                      label: isArabic ? 'سكينة' : 'Calm',
                      icon: Icons.spa_rounded,
                      color: AxisColors.success,
                      onTap: () => _handleStart(initialMood: 'CALM FOCUS'),
                    ),
                    const SizedBox(width: 5),
                    _buildMoodPill(
                      label: isArabic ? 'تأمل' : 'Reflective',
                      icon: Icons.psychology_rounded,
                      color: AxisColors.primarySofter,
                      onTap: () => _handleStart(initialMood: 'REFLECTIVE'),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Thought Starter Sparks Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSparkChip(
                        icon: Icons.emoji_events_outlined,
                        label: isArabic ? '٣ إنجازات اليوم' : 'Top 3 Wins',
                        prompt: isArabic
                            ? '### أبرز ٣ إنجازات اليوم:\n1. \n2. \n3. '
                            : '### Top 3 Wins Today:\n1. \n2. \n3. ',
                      ),
                      const SizedBox(width: 5),
                      _buildSparkChip(
                        icon: Icons.lightbulb_outline_rounded,
                        label: isArabic ? 'دروس وأفكار' : 'Key Insights',
                        prompt: isArabic
                            ? '### أهم الدروس والأفكار المستفادة اليوم:\n- '
                            : '### Key Lessons & Insights Today:\n- ',
                      ),
                      const SizedBox(width: 5),
                      _buildSparkChip(
                        icon: Icons.favorite_border_rounded,
                        label: isArabic ? 'لحظات الامتنان' : 'Gratitude',
                        prompt: isArabic
                            ? '### أشياء أنا ممتن لها اليوم:\n- '
                            : '### What I\'m Grateful For Today:\n- ',
                      ),
                      const SizedBox(width: 5),
                      _buildSparkChip(
                        icon: Icons.flag_outlined,
                        label: isArabic ? 'أولوية الغد' : 'Next Focus',
                        prompt: isArabic
                            ? '### الأولوية القصوى للغد:\n- '
                            : '### Main Priority For Tomorrow:\n- ',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 7),

                // Hero CTA Button
                InkWell(
                  onTap: () => _handleStart(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          themeAccent,
                          Color.lerp(themeAccent, const Color(0xFF0369A1), 0.4) ?? AxisColors.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: themeAccent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_note_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Flexible(
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
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
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
                            Icon(
                              isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
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
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
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

  Widget _buildSparkChip({
    required String label,
    required String prompt,
    IconData? icon,
  }) {
    return InkWell(
      onTap: () => _handleStart(initialPrompt: prompt),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AxisColors.surfaceHigh.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AxisColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: AxisColors.textDim),
              const SizedBox(width: 3.5),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                color: AxisColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _computeWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }
}
