import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'companion_badges_list.dart';

/// Obsidian Cyberpunk modal presenting a companion's full profile:
/// Username, Level, Total XP, Streak, Today's Prayers, Daily Habits, and Completed Badges.
class CompanionProfileModal extends StatefulWidget {
  final DailyPrayerStatus status;
  final FriendUser? friendUser;
  final bool isDesktop;

  const CompanionProfileModal({
    super.key,
    required this.status,
    this.friendUser,
    this.isDesktop = false,
  });

  static Future<void> showSheet(
    BuildContext context,
    DailyPrayerStatus status, [
    FriendUser? friendUser,
  ]) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CompanionProfileModal(
        status: status,
        friendUser: friendUser,
        isDesktop: false,
      ),
    );
  }

  static Future<void> showCompanionDialog(
    BuildContext context,
    DailyPrayerStatus status, [
    FriendUser? friendUser,
  ]) {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
          child: CompanionProfileModal(
            status: status,
            friendUser: friendUser,
            isDesktop: true,
          ),
        ),
      ),
    );
  }

  @override
  State<CompanionProfileModal> createState() => _CompanionProfileModalState();
}

class _CompanionProfileModalState extends State<CompanionProfileModal> {
  final _friendRepo = FriendRepository();
  StreamSubscription? _triggerSub;
  bool _copied = false;
  int _level = 1;
  int _totalXp = 0;
  String _friendCode = '';
  String _title = 'Specialist';
  bool _loadingProfile = true;
  List<MasteryBadgeData> _badges = [];
  late DailyPrayerStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _loadCompanionDetails();
  }

  @override
  void dispose() {
    _triggerSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCompanionDetails() async {
    final companionUid = widget.status.userId;
    int lvl = widget.friendUser?.level ?? 1;
    int xp = widget.friendUser?.totalXp ?? 0;
    String code = widget.friendUser?.friendCode ?? '';
    String title = widget.friendUser?.title ?? 'Specialist';

    // 1. Check inMemoryProfileCache populated by direct Supabase sync
    final cachedProf = FriendSearchRepository().inMemoryProfileCache[companionUid];
    if (cachedProf != null) {
      if (cachedProf['level'] != null) lvl = parseToInt(cachedProf['level'], lvl);
      if (cachedProf['total_xp'] != null) xp = parseToInt(cachedProf['total_xp'], xp);
      if (cachedProf['friend_code'] != null && cachedProf['friend_code'].toString().isNotEmpty) {
        code = cachedProf['friend_code'].toString();
      }
      if (cachedProf['title'] != null && cachedProf['title'].toString().isNotEmpty) {
        title = cachedProf['title'].toString();
      }
    }

    // 2. Fall back to local SQLite if present
    if (isDatabaseInitialized && companionUid.isNotEmpty) {
      try {
        final row = await db.getOptional(
          'SELECT level, total_xp, friend_code, title FROM user_profiles WHERE user_id = ? LIMIT 1',
          [companionUid],
        );
        if (row != null) {
          if (row['level'] != null) lvl = (row['level'] as num).toInt();
          if (row['total_xp'] != null) xp = (row['total_xp'] as num).toInt();
          if (row['friend_code'] != null && row['friend_code'].toString().isNotEmpty) {
            code = row['friend_code'].toString();
          }
          if (row['title'] != null && row['title'].toString().isNotEmpty) {
            title = row['title'].toString();
          }
        }
      } catch (_) {}
    }

    // 3. Authoritatively fetch live companion metadata directly from Supabase
    if (_friendRepo.isRemoteAuthenticated && companionUid.isNotEmpty) {
      try {
        final remoteProf = await Supabase.instance.client
            .from('user_profiles')
            .select('level, total_xp, friend_code, title')
            .eq('user_id', companionUid)
            .maybeSingle();
        if (remoteProf != null) {
          if (remoteProf['level'] != null) lvl = parseToInt(remoteProf['level'], lvl);
          if (remoteProf['total_xp'] != null) xp = parseToInt(remoteProf['total_xp'], xp);
          if (remoteProf['friend_code'] != null && remoteProf['friend_code'].toString().isNotEmpty) {
            code = remoteProf['friend_code'].toString();
          }
          if (remoteProf['title'] != null && remoteProf['title'].toString().isNotEmpty) {
            title = remoteProf['title'].toString();
          }
          FriendSearchRepository().inMemoryProfileCache[companionUid] = remoteProf;
        }
      } catch (_) {}
    }

    if (code.isEmpty) {
      final hashPart = companionUid.replaceAll('-', '').toUpperCase();
      code = 'AX-${hashPart.length >= 4 ? hashPart.substring(0, 4) : "7842"}';
    }

    final badges = await _friendRepo.getBadgesForCompanion(
      companionUid,
      level: lvl,
      totalXp: xp,
    );

    if (mounted) {
      setState(() {
        _level = lvl;
        _totalXp = xp;
        _friendCode = code;
        _title = title;
        _badges = badges;
        _loadingProfile = false;
      });
    }
  }

  void _copyFriendCode() {
    if (_friendCode.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _friendCode));
    HapticFeedback.lightImpact();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _currentStatus;
    final isArabic = l10n.isArabic;

    final content = Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(widget.isDesktop ? 20 : 28),
        border: Border.all(color: AxisColors.borderActive.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Handle or Window Header
          if (!widget.isDesktop) ...[
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AxisColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 0),
              child: Row(
                children: [
                  Text(
                    l10n.companionProfile.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AxisColors.secondary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          ],

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar & Identity Card
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AxisColors.primary.withValues(alpha: 0.8),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AxisColors.primary.withValues(alpha: 0.25),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: AvatarWidget(
                            name: status.userName,
                            avatarColor: status.userAvatarColor,
                            avatarUrl: status.userAvatarUrl,
                            size: 68,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                status.userName,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AxisColors.textHigh,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AxisColors.primary.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AxisColors.primarySoft.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                'LVL $_level',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AxisColors.primarySoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _title,
                          style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        // Friend Code Chip
                        InkWell(
                          onTap: _copyFriendCode,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'CODE: $_friendCode',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AxisColors.secondarySoft,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                                  size: 13,
                                  color: _copied ? AxisColors.tertiary : AxisColors.textDim,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Profile Metrics: Level & Discipline XP
                  Row(
                    children: [
                      // Level
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.military_tech_rounded,
                          iconColor: AxisColors.primarySoft,
                          title: 'LVL $_level',
                          subtitle: isArabic ? 'المستوى' : 'Level',
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Discipline XP
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.bolt_rounded,
                          iconColor: AxisColors.warning,
                          title: '$_totalXp XP',
                          subtitle: isArabic ? 'نقاط الانضباط' : 'Discipline XP',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Completed Badges Section
                  CompanionBadgesList(
                    badges: _badges,
                    isLoading: _loadingProfile,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.isDesktop) {
      return content;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: MediaQuery.of(context).padding.top + 40,
      ),
      child: content,
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w800, color: AxisColors.textHigh), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(subtitle, style: GoogleFonts.getFont('Geist', fontSize: 9.5, color: AxisColors.textDim), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
