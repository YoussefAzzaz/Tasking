import 'dart:async';
import 'package:flutter/material.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:axis/data/note_repository.dart';
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'package:axis/ui/me/widgets/me_sections.dart' show BadgeDetailSheet;
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/ui/today/widgets/xp_cockpit_card.dart';
import 'package:axis/ui/today/widgets/micro_slots_section.dart';
import 'package:axis/ui/today/widgets/priority_task_card.dart';
import 'package:axis/ui/today/widgets/next_milestones_card.dart';
import 'package:axis/ui/today/widgets/today_prayer_times_card.dart';
import 'package:axis/ui/notes/widgets/daily_journal_card.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/notes/widgets/note_detail_sheet.dart';

export 'package:axis/ui/today/widgets/priority_task_card.dart';
export 'package:axis/ui/today/widgets/time_slot_card.dart';
export 'package:axis/ui/today/widgets/xp_cockpit_card.dart';
export 'package:axis/ui/today/widgets/micro_slots_section.dart';
export 'package:axis/ui/today/widgets/next_milestones_card.dart';
export 'package:axis/ui/today/widgets/today_prayer_times_card.dart';

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

  void _openCreateJournal({Note? noteToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateNoteSheet(
        initialCategory: 'journal',
        noteToEdit: noteToEdit,
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
          final title = note.title.isNotEmpty ? note.title : 'Entry';
          await _noteRepo.deleteNote(note.id);
          setState(() {});
          if (mounted) {
            AxisSnackBar.showDeleted(context, itemTitle: title, itemType: 'Note');
          }
        },
      ),
    );
  }

  Future<void> _toggleTaskStatus(Task task, bool isDone) async {
    // Optimistic UI update
    final deltaXp = (task.priority == 1 ? 75 : (task.priority == 2 ? 50 : 25)) * (isDone ? 1 : -1);
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
    final now = DateTime.now();
    final dayLabel = DateFormat('EEEE').format(now).toUpperCase();
    final dateLabel = DateFormat('d MMM yyyy').format(now);

    final level = GamificationEngine.calculateLevel(_totalXp);
    final currentLevelBaseXp = GamificationEngine.xpToReachLevel(level);
    final nextLevelXp = GamificationEngine.xpToReachLevel(level + 1);
    final span = nextLevelXp - currentLevelBaseXp;
    final progress =
        span > 0 ? ((_totalXp - currentLevelBaseXp) / span).clamp(0.0, 1.0) : 0.0;
    final rank = level >= 10
        ? 'CYBER KINETIC'
        : (level >= 5 ? 'CYBER OPERATIVE' : 'CYBER INITIATE');

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
                    _buildNotificationBell(context),
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
                _buildPriorityMatrixHeader(context, pendingTasks.length),

                const SizedBox(height: 10),

                if (pendingTasks.isEmpty)
                  _buildEmptyPriorityMatrix(context)
                else
                  ...pendingTasks.map((task) {
                    final isDone = task.status == 'done';
                    final badge = task.priority == 1
                        ? 'P1 CRITICAL'
                        : (task.priority == 2 ? 'P2 MEDIUM' : 'P3 LOW');
                    final xp = task.priority == 1
                        ? 75
                        : (task.priority == 2 ? 50 : 25);
                    final tag = task.tags != null && task.tags!.isNotEmpty
                        ? '@${task.tags!.split(',').first.trim().replaceAll('@', '')}'
                        : (task.projectId != null
                            ? '#${task.projectId}'
                            : 'Task');
                    final estimate = '${task.estimateMin ?? 15}m';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PriorityTaskCard(
                        priority: task.priority ?? 3,
                        badge: badge,
                        estimate: estimate,
                        tag: tag,
                        title: task.title,
                        subtitle: task.notes ??
                            (task.dueDate != null
                                ? 'Due: ${task.dueDate}'
                                : 'No notes added'),
                        xp: xp,
                        isDone: isDone,
                        onToggle: (v) => _toggleTaskStatus(task, v),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => TaskDetailSheet(
                              task: task,
                              onTaskUpdated: (_) {
                                _loadStats();
                                _loadMilestones();
                              },
                            ),
                          );
                        },
                      ),
                    );
                  }),

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

                    return DailyJournalCard(
                      todayJournal: todayJournal,
                      onOpenTodayJournal: (note) => _showJournalDetail(note),
                      onStartNewJournal: () => _openCreateJournal(),
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

  Widget _buildPriorityMatrixHeader(BuildContext context, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.view_timeline_rounded,
                  color: AxisColors.primarySoft, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'PRIORITY MATRIX',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count REMAINING',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AxisColors.textMuted,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyPriorityMatrix(BuildContext context) {
    return AxisCard(
      tier: GlassTier.one,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AxisColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AxisColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(Icons.done_all_rounded,
                  color: AxisColors.primary, size: 22),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Tasks For Today',
              style: TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your priority matrix for today is clean. Add a task to get started.',
              style: TextStyle(
                color: AxisColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => CreateTaskSheet(
                    onTaskCreated: () {
                      _loadStats();
                      _loadMilestones();
                    },
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AxisColors.primary,
                      Color(0xFF6366F1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Create Task',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // IN-APP NOTIFICATIONS BELL & DIALOG / BOTTOM SHEET
  // ===========================================================================
  Widget _buildNotificationBell(BuildContext context) {
    return StreamBuilder<List<FriendUser>>(
      stream: _friendRepo.watchPendingRequests(),
      builder: (context, pendingSnap) {
        final pendingCount = pendingSnap.data?.length ?? 0;
        return StreamBuilder<List<FriendActivityLog>>(
          stream: _friendRepo.watchFriendActivityLogs(),
          builder: (context, logSnap) {
            final logs = logSnap.data ?? [];
            final totalBadge = pendingCount + logs.length;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showNotificationsSheet(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: totalBadge > 0
                          ? AxisColors.primary.withValues(alpha: 0.6)
                          : AxisColors.borderSubtle,
                      width: 1,
                    ),
                    boxShadow: totalBadge > 0
                        ? [
                            BoxShadow(
                              color: AxisColors.primary.withValues(alpha: 0.22),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        totalBadge > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        size: 19,
                        color: totalBadge > 0
                            ? AxisColors.primarySoft
                            : AxisColors.textDim,
                      ),
                      if (totalBadge > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AxisColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$totalBadge',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final l10n = AppLocalizations.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: AxisColors.canvasBase,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AxisColors.borderGlass2, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: AxisColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AxisColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_rounded,
                              size: 18, color: AxisColors.primarySoft),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.friendNotifications,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.textHigh,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _friendRepo.clearFriendNotifications();
                          },
                          child: Text(
                            l10n.clearNotifications,
                            style: GoogleFonts.getFont('Geist',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textDim),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AxisColors.textDim),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AxisColors.borderSubtle, height: 1),

                  // List Content
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        // 1. Pending Friend Requests Section
                        StreamBuilder<List<FriendUser>>(
                          stream: _friendRepo.watchPendingRequests(),
                          builder: (context, pendingSnap) {
                            final requests = pendingSnap.data ?? [];
                            if (requests.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_add_rounded,
                                        size: 14, color: AxisColors.primarySoft),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.pendingRequests.toUpperCase(),
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: AxisColors.textDim,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AxisColors.primary,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        '${requests.length}',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...requests.map((r) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AxisColors.surfaceLowest,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: AxisColors.primary
                                                .withValues(alpha: 0.35)),
                                      ),
                                      child: Row(
                                        children: [
                                          AvatarWidget(
                                            name: r.name,
                                            avatarColor: r.avatarColor,
                                            avatarUrl: r.avatarUrl,
                                            size: 42,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.name,
                                                  style: GoogleFonts.spaceGrotesk(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AxisColors.textHigh,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Lv. ${r.level} · ${r.friendCode ?? ''}',
                                                  style: GoogleFonts.getFont('Geist',
                                                      fontSize: 11,
                                                      color: AxisColors.textDim),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () async {
                                              HapticFeedback.lightImpact();
                                              await _friendRepo.declineFriendRequest(
                                                  r.friendshipId, r.userId);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AxisColors.error,
                                              side: BorderSide(
                                                  color: AxisColors.error
                                                      .withValues(alpha: 0.5)),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              minimumSize: const Size(54, 32),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                            child: Text(
                                              l10n.refuse,
                                              style: GoogleFonts.getFont('Geist',
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () async {
                                              HapticFeedback.lightImpact();
                                              await _friendRepo.acceptFriendRequest(
                                                  r.friendshipId, r.userId);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AxisColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              minimumSize: const Size(60, 32),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                            child: Text(
                                              l10n.accept,
                                              style: GoogleFonts.getFont('Geist',
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 14),
                              ],
                            );
                          },
                        ),

                        // 2. Activity Logs & Reminders Section
                        StreamBuilder<List<FriendActivityLog>>(
                          stream: _friendRepo.watchFriendActivityLogs(),
                          builder: (context, logSnap) {
                            final logs = logSnap.data ?? [];

                            return StreamBuilder<List<FriendUser>>(
                              stream: _friendRepo.watchPendingRequests(),
                              builder: (context, pendingSnap) {
                                final requests = pendingSnap.data ?? [];
                                if (logs.isEmpty && requests.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.notifications_none_rounded,
                                              size: 40, color: AxisColors.textDim),
                                          const SizedBox(height: 12),
                                          Text(
                                            l10n.noNotificationsYet,
                                            style: GoogleFonts.getFont('Geist',
                                                fontSize: 13,
                                                color: AxisColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                if (logs.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.history_rounded,
                                            size: 14, color: AxisColors.textDim),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.friendNotifications.toUpperCase(),
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: AxisColors.textDim,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...logs.map((log) {
                                      final icon = log.isPrayerReminder
                                          ? Icons.notifications_active_rounded
                                          : (log.isRequestAccepted
                                              ? Icons.check_circle_outline_rounded
                                              : (log.isRequestDeclined
                                                  ? Icons.cancel_outlined
                                                  : Icons.info_outline_rounded));
                                      final iconColor = log.isPrayerReminder
                                          ? AxisColors.primarySoft
                                          : (log.isRequestAccepted
                                              ? AxisColors.success
                                              : (log.isRequestDeclined
                                                  ? AxisColors.error
                                                  : AxisColors.warning));

                                      String dateStr = '';
                                      try {
                                        final dt = DateTime.parse(log.createdAt).toLocal();
                                        dateStr = DateFormat('h:mm a').format(dt);
                                      } catch (_) {}

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AxisColors.surfaceLowest,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AxisColors.borderSubtle),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: iconColor.withValues(alpha: 0.14),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(icon, size: 16, color: iconColor),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    log.title,
                                                    style: GoogleFonts.getFont('Geist',
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: AxisColors.textHigh),
                                                  ),
                                                  if (dateStr.isNotEmpty)
                                                    Text(
                                                      dateStr,
                                                      style: GoogleFonts.spaceGrotesk(
                                                          fontSize: 10.5,
                                                          color: AxisColors.textDim),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
