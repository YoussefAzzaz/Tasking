import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_prayer_board.dart';
import '../widgets/desktop_companions_sidebar_tabs.dart';
import '../widgets/desktop_add_companion_dialog.dart';

/// Desktop Screen dedicated to Companions & Mutual Prayer/Habit Accountability.
class FriendsAccountabilityScreen extends StatefulWidget {
  const FriendsAccountabilityScreen({super.key});

  @override
  State<FriendsAccountabilityScreen> createState() => _FriendsAccountabilityScreenState();
}

class _FriendsAccountabilityScreenState extends State<FriendsAccountabilityScreen> {
  final _friendRepo = FriendRepository();
  final _profileRepo = UserProfileRepository();

  @override
  void initState() {
    super.initState();
    _friendRepo.syncAllFriendData();
  }

  void _openAddCompanionDialog() {
    // Root cause: fell back to fake 'AX-7842' before profile friendCode loaded.
    final code = _profileRepo.resolveDisplayFriendCode();
    DesktopAddCompanionDialog.show(context, code);
  }

  void _showNotificationPopover(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          constraints: const BoxConstraints(maxHeight: 460),
          decoration: BoxDecoration(
            color: AxisColors.canvasBase,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AxisColors.borderSubtle),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, size: 18, color: AxisColors.tertiaryBright),
                  const SizedBox(width: 8),
                  Text(l10n.friendNotifications, style: AxisFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: AxisColors.textHigh)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      _friendRepo.clearFriendNotifications();
                      Navigator.of(ctx).pop();
                    },
                    child: Text(l10n.clearNotifications, style: const TextStyle(fontSize: 11, color: AxisColors.textDim)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<FriendActivityLog>>(
                  stream: _friendRepo.watchFriendActivityLogs(),
                  builder: (context, snapshot) {
                    final logs = snapshot.data ?? [];
                    if (logs.isEmpty) {
                      return Center(
                        child: Text(l10n.noNotificationsYet, style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim)),
                      );
                    }
                    return ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _friendRepo.dismissNotification(log.id),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(color: AxisColors.surfaceLowest, borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(log.title, style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 14, color: AxisColors.textDim),
                                    onPressed: () => _friendRepo.dismissNotification(log.id),
                                    tooltip: l10n.isArabic ? 'إخفاء' : 'Dismiss',
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return Padding(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AxisColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.group_rounded, color: AxisColors.primarySoft, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isArabic ? 'الرفاق والمحاسبة المشتركة' : 'COMPANIONS & MUTUAL ACCOUNTABILITY',
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AxisColors.textHigh,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      isArabic ? 'متابعة حية للصلوات والعادات والترتيب مع رفاقك' : 'Live sync of prayers, daily habits & rankings with your circle',
                      style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Friend Code Badge
              ValueListenableBuilder<UserProfile>(
                valueListenable: _profileRepo.profileNotifier,
                builder: (context, profile, _) {
                  // Root cause: fell back to hardcoded fake 'AX-7842' when friendCode wasn't loaded.
                  final myCode = _profileRepo.resolveDisplayFriendCode(profile);
                  final canCopy = myCode.isNotEmpty && myCode != '---';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AxisColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('CODE: $myCode', style: AxisFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: AxisColors.primarySoft)),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: canCopy
                              ? () {
                                  Clipboard.setData(ClipboardData(text: myCode));
                                  AxisSnackBar.show(context, message: l10n.copyCodeSuccess, icon: Icons.copy_rounded);
                                }
                              : null,
                          child: Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: canCopy ? AxisColors.textDim : AxisColors.textDim.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),

              // Notification Bell
              StreamBuilder<List<FriendActivityLog>>(
                stream: _friendRepo.watchFriendActivityLogs(),
                builder: (context, snapshot) {
                  final unread = snapshot.data?.length ?? 0;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, size: 20, color: AxisColors.textHigh),
                        onPressed: () => _showNotificationPopover(context),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(color: AxisColors.primary, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 6),

              AccentButton(
                label: l10n.addCompanion,
                icon: Icons.person_add_rounded,
                height: 32,
                onPressed: _openAddCompanionDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  flex: 3,
                  child: DesktopPrayerBoard(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: DesktopCompanionsSidebarTabs(onAddCompanion: _openAddCompanionDialog),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
