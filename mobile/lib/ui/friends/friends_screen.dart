import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/user_profile_repository.dart';

/// Friends & Mutual Accountability Hub screen.
/// Focuses on cooperative motivation: daily prayer checklists (Fajr -> Isha) and habit consistency.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _friendRepo = FriendRepository();
  final _profileRepo = UserProfileRepository();
  final _searchController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Ensure current user's daily status is up-to-date
    _friendRepo.syncMyDailyPrayerStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddFriendDialog(BuildContext context, String myFriendCode) {
    _searchController.clear();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AxisColors.canvasBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AxisColors.borderGlass2, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_add_alt_1_rounded, size: 20, color: AxisColors.primarySoft),
                        const SizedBox(width: 8),
                        Text(
                          'Add Companion',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AxisColors.textHigh,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter your friend\'s 6-character Friend Code (e.g. AX-7842) or display name to connect and share daily prayer & habit accountability.',
                  style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.getFont('Geist', color: AxisColors.textHigh, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. AX-8492 or Ahmad',
                    hintStyle: GoogleFonts.getFont('Geist', color: AxisColors.textDim),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AxisColors.textDim),
                    filled: true,
                    fillColor: AxisColors.surfaceLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AxisColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AxisColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOUR FRIEND CODE',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.textDim)),
                          const SizedBox(height: 2),
                          Text(myFriendCode.isNotEmpty ? myFriendCode : 'AX-7842',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: AxisColors.primarySoft)),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Copy Code',
                        icon: const Icon(Icons.copy_rounded, size: 16, color: AxisColors.primarySoft),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: myFriendCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Friend code copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () async {
                          final text = _searchController.text.trim();
                          if (text.isEmpty) return;
                          setDialogState(() => _isSubmitting = true);
                          try {
                            final success = await _friendRepo.sendFriendRequest(text);
                            if (context.mounted) {
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success
                                      ? 'Friend request sent to $text!'
                                      : 'Could not find companion with that code or name.'),
                                  backgroundColor: success ? AxisColors.success : AxisColors.warning,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: AxisColors.error),
                              );
                            }
                          } finally {
                            if (mounted) setDialogState(() => _isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AxisColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Send Connection Request',
                          style: GoogleFonts.getFont('Geist', fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      appBar: AppBar(
        backgroundColor: AxisColors.canvasBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AxisColors.textHigh),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Companions',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AxisColors.textHigh,
          ),
        ),
        actions: [
          ValueListenableBuilder<UserProfile>(
            valueListenable: _profileRepo.profileNotifier,
            builder: (context, profile, _) {
              final code = profile.friendCode ?? 'AX-7842';
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: InkWell(
                  onTap: () => _showAddFriendDialog(context, code),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AxisColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_alt_1_rounded, size: 14, color: AxisColors.primarySoft),
                        const SizedBox(width: 5),
                        Text(
                          '+ Add Companion',
                          style: GoogleFonts.getFont('Geist',
                              fontSize: 11, fontWeight: FontWeight.w600, color: AxisColors.primarySoft),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AxisColors.primary,
          indicatorWeight: 2,
          labelColor: AxisColors.textHigh,
          unselectedLabelColor: AxisColors.textDim,
          labelStyle: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: "Today's Board"),
            Tab(text: 'Weekly Standings'),
            Tab(text: 'Circle'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodaysPrayerBoard(todayStr),
          _buildWeeklyStandings(),
          _buildCircleTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: Today's Prayer & Habit Checklist Board
  // ===========================================================================
  Widget _buildTodaysPrayerBoard(String todayStr) {
    return RefreshIndicator(
      onRefresh: () async {
        await _friendRepo.syncMyDailyPrayerStatus();
      },
      color: AxisColors.primary,
      backgroundColor: AxisColors.surfaceLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Gentle banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AxisColors.primary.withValues(alpha: 0.18),
                  AxisColors.tertiary.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderGlass2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AxisColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mosque_rounded, color: AxisColors.primarySoft, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY\'S PRAYER ACCOUNTABILITY',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AxisColors.primarySoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Inspire and remind each other. See who has prayed today and stay consistent together.',
                        style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Stream of Checklist rows
          StreamBuilder<List<DailyPrayerStatus>>(
            stream: _friendRepo.watchTodayChecklist(),
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Icon(Icons.group_outlined, size: 40, color: AxisColors.textDim),
                        const SizedBox(height: 10),
                        Text(
                          'No companions connected yet',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AxisColors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add a friend with their friend code to share daily prayer consistency.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: list.map((status) => _buildCompanionChecklistCard(status)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompanionChecklistCard(DailyPrayerStatus status) {
    final prayers = [
      {'code': 'fajr', 'name': 'Fajr', 'done': status.fajr},
      {'code': 'dhuhr', 'name': 'Dhuhr', 'done': status.dhuhr},
      {'code': 'asr', 'name': 'Asr', 'done': status.asr},
      {'code': 'maghrib', 'name': 'Maghrib', 'done': status.maghrib},
      {'code': 'isha', 'name': 'Isha', 'done': status.isha},
    ];

    final isMe = status.userName == 'You';
    final cardColor = isMe ? AxisColors.surfaceLow : AxisColors.surfaceLowest;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? AxisColors.primary.withValues(alpha: 0.4) : AxisColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar + Name + Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(int.tryParse(status.userAvatarColor.replaceAll('#', '0xFF')) ?? 0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        status.userName.isNotEmpty ? status.userName[0].toUpperCase() : 'C',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            status.userName,
                            style: GoogleFonts.getFont(
                              'Geist',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AxisColors.textHigh,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AxisColors.primary.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('YOU',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 9, fontWeight: FontWeight.bold, color: AxisColors.primarySoft)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${status.completedCount}/5 prayers completed today',
                        style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 15, color: AxisColors.warning),
                  const SizedBox(width: 3),
                  Text(
                    '${status.streakDays}d streak',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AxisColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 5 Prayers Checklist Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: prayers.map((p) {
              final isDone = p['done'] as bool;
              final name = p['name'] as String;

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AxisColors.tertiary.withValues(alpha: 0.15)
                        : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDone
                          ? AxisColors.tertiary.withValues(alpha: 0.7)
                          : AxisColors.borderSubtle.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 15,
                        color: isDone ? AxisColors.tertiary : AxisColors.textDim,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                          color: isDone ? AxisColors.textHigh : AxisColors.textDim,
                        ),
                      ),
                      if (!isDone && !isMe) ...[
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: () {
                            _friendRepo.sendPrayerReminder(status.userId, name);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sent reminder for $name prayer to ${status.userName} 🕌'),
                                backgroundColor: AxisColors.primary,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AxisColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.notifications_active_outlined,
                                size: 11, color: AxisColors.primarySoft),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          // Habit completion progress summary
          if (status.habitsTotal > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.repeat_rounded, size: 12, color: AxisColors.textDim),
                const SizedBox(width: 4),
                Text(
                  'Daily Habits: ${status.habitsDone}/${status.habitsTotal} completed',
                  style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
                ),
                const Spacer(),
                if (status.habitsDone == status.habitsTotal && status.habitsTotal > 0)
                  Text(
                    'All completed ✨',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.tertiary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: Weekly Friendly Standings
  // ===========================================================================
  Widget _buildWeeklyStandings() {
    return StreamBuilder<List<FriendUser>>(
      stream: _friendRepo.watchAcceptedFriends(),
      builder: (context, snapshot) {
        final friends = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.military_tech_rounded, size: 24, color: AxisColors.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CIRCLE STANDINGS',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AxisColors.warning,
                          ),
                        ),
                        Text(
                          'Supportive weekly progress. Rank based on total discipline XP.',
                          style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (friends.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    'No friends connected yet. Add companions to view standings!',
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                  ),
                ),
              )
            else
              ...List.generate(friends.length, (index) {
                final f = friends[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '#${index + 1}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: index == 0 ? AxisColors.warning : AxisColors.textDim,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(int.tryParse(f.avatarColor.replaceAll('#', '0xFF')) ?? 0xFF6366F1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            f.name.isNotEmpty ? f.name[0].toUpperCase() : 'C',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.name,
                              style: GoogleFonts.getFont('Geist', fontSize: 13, fontWeight: FontWeight.w600, color: AxisColors.textHigh),
                            ),
                            Text(
                              'Lv. ${f.level}  ·  ${f.title}',
                              style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${f.totalXp} XP',
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: AxisColors.primarySoft),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: Circle & Requests
  // ===========================================================================
  Widget _buildCircleTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pending Requests section
        StreamBuilder<List<FriendUser>>(
          stream: _friendRepo.watchPendingRequests(),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PENDING REQUESTS (${requests.length})',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: AxisColors.primarySoft),
                ),
                const SizedBox(height: 8),
                ...requests.map((r) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AxisColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name,
                                    style: GoogleFonts.getFont('Geist',
                                        fontSize: 13, fontWeight: FontWeight.w600, color: AxisColors.textHigh)),
                                Text('wants to be companions with you',
                                    style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: AxisColors.success, size: 20),
                            onPressed: () => _friendRepo.acceptFriendRequest(r.friendshipId),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_rounded, color: AxisColors.error, size: 20),
                            onPressed: () => _friendRepo.removeFriendship(r.friendshipId),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
              ],
            );
          },
        ),

        // Connected Friends List
        StreamBuilder<List<FriendUser>>(
          stream: _friendRepo.watchAcceptedFriends(),
          builder: (context, snapshot) {
            final friends = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONNECTED COMPANIONS (${friends.length})',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: AxisColors.textMuted),
                ),
                const SizedBox(height: 8),
                if (friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No companions connected yet. Use "+ Add Companion" at the top to connect!',
                        style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                      ),
                    ),
                  )
                else
                  ...friends.map((f) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(int.tryParse(f.avatarColor.replaceAll('#', '0xFF')) ?? 0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(f.name.isNotEmpty ? f.name[0].toUpperCase() : 'C',
                                    style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.name,
                                      style: GoogleFonts.getFont('Geist',
                                          fontSize: 13, fontWeight: FontWeight.w600, color: AxisColors.textHigh)),
                                  Text(
                                    'Code: ${f.friendCode ?? "AX-7842"} · Lv. ${f.level}',
                                    style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AxisColors.textDim),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AxisColors.surfaceLow,
                                    title: Text('Remove Companion',
                                        style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh)),
                                    content: Text('Remove ${f.name} from your accountability companions?',
                                        style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted)),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('Remove', style: TextStyle(color: AxisColors.error)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _friendRepo.removeFriendship(f.friendshipId);
                                }
                              },
                            ),
                          ],
                        ),
                      )),
              ],
            );
          },
        ),
      ],
    );
  }
}
