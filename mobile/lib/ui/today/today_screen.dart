import 'dart:async';
import 'package:flutter/material.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/powersync_db.dart' show globalUserLevel;
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/prayers/adhan_permissions_sheet.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/ui/me/widgets/me_sections.dart' show BadgeDetailSheet;
import 'package:axis/ui/today/widgets/xp_cockpit_card.dart';
import 'package:axis/ui/today/widgets/micro_slots_section.dart';
import 'package:axis/ui/today/widgets/next_milestones_card.dart';
import 'package:axis/ui/today/widgets/today_prayer_times_card.dart';
import 'package:axis/ui/today/widgets/today_notification_bell.dart';
import 'package:axis/ui/today/widgets/today_priority_matrix_section.dart';
import 'package:axis/ui/notes/widgets/daily_journal_card.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/notes/widgets/note_detail_sheet.dart';

export 'package:axis/ui/today/widgets/priority_task_card.dart';
export 'package:axis/ui/today/widgets/time_slot_card.dart';
export 'package:axis/ui/today/widgets/xp_cockpit_card.dart';
export 'package:axis/ui/today/widgets/micro_slots_section.dart';
export 'package:axis/ui/today/widgets/next_milestones_card.dart';
export 'package:axis/ui/today/widgets/today_prayer_times_card.dart';
export 'package:axis/ui/today/widgets/today_notification_bell.dart';
export 'package:axis/ui/today/widgets/today_priority_matrix_section.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    this.taskRepo,
    this.statsRepo,
    this.prayerService,
    this.noteRepo,
  });

  final TaskRepository? taskRepo;
  final StatsRepository? statsRepo;
  final PrayerTimeService? prayerService;
  final NoteRepository? noteRepo;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _totalXp = 0;
  int _todayXp = 0;
  int _streakDays = 0;
  List<MasteryBadgeData> _spotlightBadges = [];
  StreamSubscription<UserStats>? _statsSub;
  late final Stream<List<Task>> _tasksStream;
  late final Stream<List<Prayer>> _prayersStream;
  late final Stream<List<Note>> _notesStream;
  late final TaskRepository _taskRepo;
  late final StatsRepository _statsRepo;
  late final PrayerTimeService _prayerService;
  late final NoteRepository _noteRepo;
  final _friendRepo = FriendRepository();

  @override
  void initState() {
    super.initState();
    _friendRepo.syncAllFriendData();
    _taskRepo = widget.taskRepo ?? TaskRepository();
    _statsRepo = widget.statsRepo ?? StatsRepository();
    _prayerService = widget.prayerService ?? PrayerTimeService();
    _noteRepo = widget.noteRepo ?? NoteRepository();
    _tasksStream = _taskRepo.watchTasks();
    _prayersStream = _prayerService.watchPrayers();
    _notesStream = _noteRepo.watchNotes();
    _loadStats();
    _loadMilestones();
    _statsSub = _statsRepo.watchStats().listen((stats) {
      if (mounted) {
        setState(() {
          _totalXp = stats.totalXp;
          _todayXp = stats.todayXp;
          _streakDays = stats.streakDays;
        });
      }
    });
    globalUserLevel.addListener(_onGlobalLevelChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AdhanPermissionsSheet.checkAndShowFirstTime(context);
      }
    });
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    globalUserLevel.removeListener(_onGlobalLevelChanged);
    super.dispose();
  }

  void _onGlobalLevelChanged() {
    _loadStats(forceRefresh: true);
    _loadMilestones();
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    try {
      final stats = await _statsRepo.getUserStats(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _totalXp = stats.totalXp;
          _todayXp = stats.todayXp;
          _streakDays = stats.streakDays;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMilestones() async {
    try {
      final spotlight = await MasteryBadgeRepository().getSpotlightBadges();
      if (mounted) {
        setState(() {
          _spotlightBadges = spotlight;
        });
      }
    } catch (_) {}
  }

  void _showBadgeDetail(MasteryBadgeData badge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BadgeDetailSheet(badge: badge),
    );
  }

  void _openCreateJournal({
    Note? noteToEdit,
    String? initialMood,
    String? initialPrompt,
    bool appendTimestamp = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateNoteSheet(
        initialCategory: 'journal',
        noteToEdit: noteToEdit,
        initialMood: initialMood,
        initialBodyPrompt: initialPrompt,
        appendTimestampOnEdit: appendTimestamp,
        onNoteCreated: () => setState(() {}),
      ),
    );
  }

  void _showJournalDetail(Note note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NoteDetailSheet(
        note: note,
        onEdit: () => _openCreateJournal(noteToEdit: note),
        onDelete: () async {
          final title = note.title.isNotEmpty ? note.title : (context.isArabic ? 'تدوينة' : 'Entry');
          await _noteRepo.deleteNote(note.id);
          setState(() {});
          if (mounted) {
            AxisSnackBar.showDeleted(context, itemTitle: title, itemType: context.isArabic ? 'ملاحظة' : 'Note');
          }
        },
      ),
    );
  }

  Future<void> _toggleTaskStatus(Task task, bool isDone) async {
    // Optimistic UI update calibrated to GamificationEngine authoritative values
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isOnTime = task.dueDate == null || task.dueDate!.isEmpty || todayStr.compareTo(task.dueDate!) <= 0;
    final unitXp = GamificationEngine.taskCompletionXp(priority: task.priority, isOnTime: isOnTime);
    final deltaXp = unitXp * (isDone ? 1 : -1);
    setState(() {
      _totalXp = (_totalXp + deltaXp).clamp(0, 9999999);
      _todayXp = (_todayXp + deltaXp).clamp(0, 9999999);
    });

    await _taskRepo.toggleTaskStatus(task, isDone);
    _loadStats(forceRefresh: true);
    MasteryBadgeRepository().invalidateCache();
    _loadMilestones();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    final now = DateTime.now();
    final dayLabel = isArabic
        ? context.formatDate(now, 'EEEE')
        : DateFormat('EEEE').format(now).toUpperCase();
    final dateLabel = isArabic
        ? context.formatDate(now, 'd MMMM yyyy')
        : DateFormat('d MMM yyyy').format(now);

    final level = GamificationEngine.calculateLevel(_totalXp);
    final currentLevelBaseXp = GamificationEngine.xpToReachLevel(level);
    final nextLevelXp = GamificationEngine.xpToReachLevel(level + 1);
    final span = nextLevelXp - currentLevelBaseXp;
    final progress =
        span > 0 ? ((_totalXp - currentLevelBaseXp) / span).clamp(0.0, 1.0) : 0.0;
    final rank = level >= 10
        ? (isArabic ? 'حركي سيبراني' : 'CYBER KINETIC')
        : (level >= 5
            ? (isArabic ? 'عميل سيبراني' : 'CYBER OPERATIVE')
            : (isArabic ? 'مبتدئ سيبراني' : 'CYBER INITIATE'));

    return StreamBuilder<List<Task>>(
      stream: _tasksStream,
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        // Filter strictly for today's active tasks, sorted by priority (P1 -> P2 -> P3)
        final pendingTasks = allTasks.where((t) {
          if (t.status == 'done') return false;
          if (t.dueDate == null || t.dueDate!.trim().isEmpty) return false;
          return t.dueDate == todayStr || t.dueDate!.startsWith(todayStr);
        }).toList()
          ..sort(compareTasksByPriority);

        final slottedTasks = allTasks.where((t) {
          final isToday = t.dueDate != null &&
              (t.dueDate == todayStr || t.dueDate!.startsWith(todayStr));
          if (!isToday) return false;
          if (t.dueTime != null && t.dueTime!.isNotEmpty) return true;
          if (t.estimateMin != null && t.estimateMin! <= 30) return true;
          return false;
        }).toList();

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // ── Date header ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dayLabel,
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AxisColors.primarySoft,
                                    ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            dateLabel,
                            style: Theme.of(context).textTheme.displaySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TodayNotificationBell(friendRepo: _friendRepo),
                    const SizedBox(width: 8),
                    StreakBadge(
                      days: _streakDays,
                      isActive: _streakDays > 0,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Dedicated Islamic Prayer Telemetry Widget ─────────────
                StreamBuilder<List<Prayer>>(
                  stream: _prayersStream,
                  builder: (context, prayerSnapshot) {
                    final prayers = (prayerSnapshot.data != null && prayerSnapshot.data!.isNotEmpty)
                        ? prayerSnapshot.data!
                        : PrayerTimeService.defaultPrayers();
                    return TodayPrayerTimesCard(
                      prayers: prayers,
                      onTogglePrayer: (prayer, done) =>
                          _prayerService.togglePrayer(prayer.id, done),
                    );
                  },
                ),

                const SizedBox(height: 18),

                // ── 1. Priority Matrix (Today's Mission - First Thing User Sees) ───
                TodayPriorityMatrixSection(
                  pendingTasks: pendingTasks,
                  onToggleTask: _toggleTaskStatus,
                  onTaskCreated: () {
                    _loadStats();
                    _loadMilestones();
                  },
                  onTaskUpdated: () {
                    _loadStats();
                    _loadMilestones();
                  },
                ),

                const SizedBox(height: 16),

                // ── Daily Journal Entry ────────────────────────────────────
                StreamBuilder<List<Note>>(
                  stream: _notesStream,
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

                    final journalNotes = notes
                        .where((n) => n.category.toLowerCase() == 'journal')
                        .toList();
                    final noteDates = journalNotes
                        .map((n) => DateFormat('yyyy-MM-dd').format(n.createdAt.toLocal()))
                        .toSet();
                    final todayStr = DateFormat('yyyy-MM-dd').format(now);
                    int journalStreak = 0;
                    DateTime checkDay = noteDates.contains(todayStr)
                        ? now
                        : now.subtract(const Duration(days: 1));
                    while (noteDates.contains(DateFormat('yyyy-MM-dd').format(checkDay))) {
                      journalStreak++;
                      checkDay = checkDay.subtract(const Duration(days: 1));
                    }

                    return DailyJournalCard(
                      todayJournal: todayJournal,
                      streak: journalStreak,
                      onOpenTodayJournal: (note) => _showJournalDetail(note),
                      onStartNewJournal: () => _openCreateJournal(),
                      onStartNewJournalWithPrompt: ({initialMood, initialPrompt}) =>
                          _openCreateJournal(initialMood: initialMood, initialPrompt: initialPrompt),
                      onAppendToTodayJournal: (note) =>
                          _openCreateJournal(noteToEdit: note, appendTimestamp: true),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ── 2. Next Milestones in Reach (Moved from Me Screen) ─────
                NextMilestonesCard(
                  spotlightBadges: _spotlightBadges,
                  onTapBadge: _showBadgeDetail,
                ),

                const SizedBox(height: 20),

                // ── 3. 15M Auto-Scheduler section ──────────────────────────
                MicroSlotsSection(
                  slottedTasks: slottedTasks,
                  onToggleTask: _toggleTaskStatus,
                ),

                const SizedBox(height: 20),

                // ── 4. XP Cockpit Card (Daily Level & XP Progress) ────────
                XpCockpitCard(
                  level: level,
                  rank: rank,
                  todayXp: _todayXp,
                  totalXp: _totalXp,
                  nextLevelXp: nextLevelXp,
                  progress: progress,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

}
