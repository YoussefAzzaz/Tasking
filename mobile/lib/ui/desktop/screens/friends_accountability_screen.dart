import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/friend_repository.dart';
import '../../../data/user_profile_repository.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/ghost_button.dart';
import '../widgets/section_header.dart';

/// Desktop Screen dedicated to Companions & Mutual Prayer/Habit Accountability.
class FriendsAccountabilityScreen extends StatefulWidget {
  const FriendsAccountabilityScreen({super.key});

  @override
  State<FriendsAccountabilityScreen> createState() => _FriendsAccountabilityScreenState();
}

class _FriendsAccountabilityScreenState extends State<FriendsAccountabilityScreen> {
  final _friendRepo = FriendRepository();
  final _profileRepo = UserProfileRepository();
  final _addFriendController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _friendRepo.syncMyDailyPrayerStatus();
  }

  @override
  void dispose() {
    _addFriendController.dispose();
    super.dispose();
  }

  void _showAddFriendDialog(BuildContext context, String myFriendCode) {
    _addFriendController.clear();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(22),
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
                          'Add Accountability Companion',
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
                  'Enter your friend\'s 6-character Friend Code (e.g. AX-7842) or username to share daily prayer and habit accountability.',
                  style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addFriendController,
                  autofocus: true,
                  style: GoogleFonts.getFont('Geist', color: AxisColors.textHigh, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. AX-7842',
                    hintStyle: GoogleFonts.getFont('Geist', color: AxisColors.textDim),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AxisColors.textDim),
                    filled: true,
                    fillColor: AxisColors.surfaceLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AxisColors.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AxisColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      GhostButton(
                        label: 'Copy Code',
                        icon: Icons.copy_rounded,
                        height: 28,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: myFriendCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Friend code copied!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AccentButton(
                  label: _isSubmitting ? 'Sending Request...' : 'Send Connection Request',
                  height: 36,
                  onPressed: _isSubmitting
                      ? () {}
                      : () async {
                          final text = _addFriendController.text.trim();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Container(
          color: AxisColors.canvasBase,
          padding: const EdgeInsets.all(DesktopLayout.panelPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  final isArabic = l10n.isArabic;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'الرفاق والمتابعة والتشجيع المتبادل'
                                  : 'Companions & Mutual Accountability',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AxisColors.textHigh,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArabic
                                  ? 'التعاون والتواصي بالخير للاستمرار في أداء الصلوات والعادات الأساسية'
                                  : 'Help each other stay steadfast in daily prayers and core habits',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      ValueListenableBuilder<UserProfile>(
                        valueListenable: _profileRepo.profileNotifier,
                        builder: (context, profile, _) {
                          final code = profile.friendCode ?? 'AX-7842';
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AxisColors.surfaceLowest,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AxisColors.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    Text(isArabic ? 'رمزي: ' : 'MY CODE: ',
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 10, fontWeight: FontWeight.bold, color: AxisColors.textDim)),
                                    Text(code,
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 12, fontWeight: FontWeight.bold, color: AxisColors.primarySoft)),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: code));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(isArabic ? 'تم نسخ الرمز!' : 'Friend code copied!')),
                                        );
                                      },
                                      child: const Icon(Icons.copy_rounded, size: 14, color: AxisColors.textDim),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              AccentButton(
                                label: l10n.addCompanion,
                                icon: Icons.person_add_alt_1_rounded,
                                height: 32,
                                onPressed: () => _showAddFriendDialog(context, code),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: DesktopLayout.sectionSpacing),

              // Main 2-Column Split
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Column: Live Prayer Checklist Matrix
                    Expanded(
                      flex: 6,
                      child: _buildPrayerMatrixCard(),
                    ),
                    const SizedBox(width: DesktopLayout.sectionSpacing),

                    // Right Column: Standings & Circle Management
                    Expanded(
                      flex: 4,
                      child: _buildRightSideCard(),
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

  Widget _buildPrayerMatrixCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'TODAY\'S PRAYER & HABIT BOARD',
            trailing: GhostButton(
              label: 'Refresh',
              icon: Icons.refresh_rounded,
              height: 26,
              onPressed: () => _friendRepo.syncMyDailyPrayerStatus(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<DailyPrayerStatus>>(
              stream: _friendRepo.watchTodayChecklist(),
              builder: (context, snapshot) {
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.group_outlined, size: 36, color: AxisColors.textDim),
                          const SizedBox(height: 8),
                          Text('No companions connected yet',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13, fontWeight: FontWeight.bold, color: AxisColors.textHigh)),
                          const SizedBox(height: 4),
                          Text('Share your friend code to start tracking daily consistency together.',
                              style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final status = list[index];
                    final isMe = status.userName == 'You';
                    final prayers = [
                      {'code': 'fajr', 'name': 'Fajr', 'done': status.fajr},
                      {'code': 'dhuhr', 'name': 'Dhuhr', 'done': status.dhuhr},
                      {'code': 'asr', 'name': 'Asr', 'done': status.asr},
                      {'code': 'maghrib', 'name': 'Maghrib', 'done': status.maghrib},
                      {'code': 'isha', 'name': 'Isha', 'done': status.isha},
                    ];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? AxisColors.surfaceLow : AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isMe ? AxisColors.primary.withValues(alpha: 0.4) : AxisColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          // User info
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
                                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 120,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  status.userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.getFont('Geist',
                                      fontSize: 12, fontWeight: FontWeight.w600, color: AxisColors.textHigh),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded,
                                        size: 12, color: AxisColors.warning),
                                    const SizedBox(width: 2),
                                    Text('${status.streakDays}d streak',
                                        style: GoogleFonts.spaceGrotesk(
                                            fontSize: 10, fontWeight: FontWeight.bold, color: AxisColors.warning)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Prayers 5 pills
                          Expanded(
                            child: Row(
                              children: prayers.map((p) {
                                final isDone = p['done'] as bool;
                                final name = p['name'] as String;

                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? AxisColors.tertiary.withValues(alpha: 0.15)
                                          : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isDone
                                            ? AxisColors.tertiary.withValues(alpha: 0.6)
                                            : AxisColors.borderSubtle.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          isDone
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked_rounded,
                                          size: 13,
                                          color: isDone ? AxisColors.tertiary : AxisColors.textDim,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          name,
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 9,
                                            fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                                            color: isDone ? AxisColors.textHigh : AxisColors.textDim,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Nudge button
                          if (!isMe) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Send reminder for current prayer',
                              icon: const Icon(Icons.notifications_active_outlined,
                                  size: 15, color: AxisColors.primarySoft),
                              onPressed: () {
                                _friendRepo.sendPrayerReminder(status.userId, 'Prayer');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Sent reminder to ${status.userName} 🕌'),
                                    backgroundColor: AxisColors.primary,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSideCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'STANDINGS & CIRCLE'),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<FriendUser>>(
              stream: _friendRepo.watchAcceptedFriends(),
              builder: (context, snapshot) {
                final friends = snapshot.data ?? [];
                if (friends.isEmpty) {
                  return Center(
                    child: Text(
                      'No companions in your circle yet.',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final f = friends[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6.0),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Text('#${index + 1}',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: index == 0 ? AxisColors.warning : AxisColors.textDim)),
                          const SizedBox(width: 10),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(int.tryParse(f.avatarColor.replaceAll('#', '0xFF')) ?? 0xFF6366F1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                f.name.isNotEmpty ? f.name[0].toUpperCase() : 'C',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.getFont('Geist',
                                        fontSize: 12, fontWeight: FontWeight.w600, color: AxisColors.textHigh)),
                                Text('Lv. ${f.level} · ${f.title}',
                                    style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim)),
                              ],
                            ),
                          ),
                          Text('${f.totalXp} XP',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11, fontWeight: FontWeight.bold, color: AxisColors.primarySoft)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
