import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/powersync_db.dart' show globalUserLevel, isDatabaseInitialized, db;
import 'package:powersync/powersync.dart' show SyncStatus;
import 'package:axis/data/network_service.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/ui/common/updates/update_notice_modal.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'package:axis/ui/common/sync_status_modal.dart';

/// Top app header — Axis brand + sync status + LVL badge + avatar
class AxisHeader extends StatefulWidget {
  const AxisHeader({super.key, required this.onAvatarTap, this.isMeSelected = false});
  final VoidCallback onAvatarTap;
  final bool isMeSelected;

  @override
  State<AxisHeader> createState() => _AxisHeaderState();
}

class _AxisHeaderState extends State<AxisHeader> {
  @override
  void initState() {
    super.initState();
    UserProfileRepository().getProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final update = await AppUpdateService().checkForUpdate();
      if (update != null && mounted) {
        final currentVer = await AppUpdateService().getInstalledVersion();
        if (!mounted) return;
        if (update.shouldPrompt(
          currentVersion: currentVer.toString(),
          currentBuildNumber: currentVer.buildNumber,
        )) {
          UpdateNoticeModal.show(context, updateInfo: update);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 10,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AxisColors.canvasBase.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Brand with App Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    cacheWidth: 64,
                    cacheHeight: 64,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AXIS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  ValueListenableBuilder<bool>(
                    valueListenable: NetworkService().isOnlineNotifier,
                    builder: (context, isOnline, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: AuthService().authStateNotifier,
                        builder: (context, _, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: AuthService().sessionExpiredNotifier,
                            builder: (context, isSessionExpired, _) {
                              return StreamBuilder<SyncStatus>(
                                stream: isDatabaseInitialized
                                    ? db.statusStream
                                    : const Stream<SyncStatus>.empty(),
                                initialData: isDatabaseInitialized ? db.currentStatus : null,
                                builder: (context, snapshot) {
                                  final auth = AuthService();
                                  final isGuest = auth.isGuest;
                                  final isArabic = context.isArabic;
                                  final syncStatus = snapshot.data;
                                  final isDbConnected =
                                      syncStatus?.connected ?? (isDatabaseInitialized && db.connected);
                                  final hasSyncError = syncStatus?.anyError != null;
                                  final isConnecting = syncStatus?.connecting ?? false;

                                  final Color dotColor;
                                  final String label;
                                  final String tooltipMsg;

                                  if (!isOnline) {
                                    dotColor = AxisColors.warning;
                                    label = isArabic ? 'غير متصل' : 'OFFLINE';
                                    tooltipMsg = isArabic
                                        ? 'غير متصل • يعمل بأمان عبر SQLite المحلي'
                                        : 'Offline • Operating securely with local SQLite';
                                  } else if (isSessionExpired) {
                                    dotColor = AxisColors.danger;
                                    label = isArabic ? 'انتهت الجلسة' : 'EXPIRED';
                                    tooltipMsg = isArabic
                                        ? 'انتهت صلاحية الجلسة • العمل محفوظ محلياً. اضغط لإعادة تسجيل الدخول'
                                        : 'Session Expired • Work saved locally in SQLite. Tap to re-login.';
                                  } else if (isGuest) {
                                    dotColor = const Color(0xFFF59E0B);
                                    label = isArabic ? 'ضيف (محلي)' : 'GUEST (LOCAL)';
                                    tooltipMsg = isArabic
                                        ? 'العمل كضيف محلي. انقر لتسجيل الدخول والمزامنة مع سطح المكتب و Supabase.'
                                        : 'Operating as local guest. Tap to sign in and sync with Desktop & Supabase.';
                                  } else if (hasSyncError) {
                                    dotColor = AxisColors.warning;
                                    label = isArabic ? 'خطأ مزامنة' : 'SYNC ERROR';
                                    tooltipMsg = isArabic
                                        ? 'تعذر اكتمال المزامنة السحابية. اضغط لفحص التفاصيل.'
                                        : 'Cloud sync encountered an issue. Tap to view diagnostics.';
                                  } else if (!isDbConnected) {
                                    if (isConnecting) {
                                      dotColor = AxisColors.secondary;
                                      label = isArabic ? 'جارٍ الاتصال' : 'CONNECTING';
                                      tooltipMsg = isArabic
                                          ? 'جارٍ الاتصال بمحرك PowerSync...'
                                          : 'Connecting to PowerSync engine...';
                                    } else {
                                      dotColor = AxisColors.warning;
                                      label = isArabic ? 'غير متزامن' : 'NOT SYNCED';
                                      tooltipMsg = isArabic
                                          ? 'غير متزامن سحابياً • العمل محفوظ محلياً. اضغط لإعادة المحاولة.'
                                          : 'Not synced with cloud • Work saved locally. Tap to retry.';
                                    }
                                  } else {
                                    dotColor = AxisColors.tertiary;
                                    label = isArabic ? 'متزامن' : 'SYNCED';
                                    tooltipMsg = isArabic
                                        ? 'متزامن سحابياً • PowerSync نشط (${auth.currentUser?.email ?? "متصل"})'
                                        : 'Cloud Synced • PowerSync active (${auth.currentUser?.email ?? "Connected"})';
                                  }

                                  return GestureDetector(
                                    onTap: () => SyncStatusModal.show(context),
                                    behavior: HitTestBehavior.opaque,
                                    child: Tooltip(
                                      message: tooltipMsg,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Sync dot (reactive to online / offline / guest / expired status)
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: dotColor,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: dotColor.withValues(alpha: 0.7),
                                                  blurRadius: 6,
                                                )
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(milliseconds: 300),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: (isOnline && isSessionExpired)
                                                          ? AxisColors.danger
                                                          : (!isOnline
                                                              ? AxisColors.warning
                                                              : (isGuest
                                                                  ? const Color(0xFFF59E0B)
                                                                  : AxisColors.textMuted)),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ) ??
                                                const TextStyle(),
                                            child: Text(label),
                                          ),
                                          if (isGuest || (isOnline && isSessionExpired)) ...[
                                            const SizedBox(width: 2),
                                            Icon(
                                              context.isArabic
                                                  ? Icons.arrow_back_ios_rounded
                                                  : Icons.arrow_forward_ios_rounded,
                                              size: 8,
                                              color: (isOnline && isSessionExpired)
                                                  ? AxisColors.danger
                                                  : const Color(0xFFF59E0B),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // LVL badge (dynamically synced)
          ValueListenableBuilder<int>(
            valueListenable: globalUserLevel,
            builder: (context, lvl, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AxisColors.secondary, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      context.isArabic ? 'مستوى $lvl' : 'LVL $lvl',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AxisColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Calendar entry button
          Tooltip(
            message: context.isArabic ? 'التقويم' : 'Calendar',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('axis_header_calendar_button'),
                onTap: () => context.push('/calendar'),
                borderRadius: BorderRadius.circular(9999),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: AxisColors.textHigh,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar → opens Me (renders real user pfp if available with active border when selected)
          ValueListenableBuilder<UserProfile>(
            valueListenable: UserProfileRepository().profileNotifier,
            builder: (context, profile, _) {
              return Tooltip(
                message: context.isArabic ? 'فتح الملف الشخصي (حسابي)' : 'Open Profile (Me)',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isMeSelected ? AxisColors.primarySoft : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: widget.isMeSelected
                        ? [
                            BoxShadow(
                              color: AxisColors.primary.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: AvatarWidget(
                    avatarUrl: profile.avatarUrl,
                    name: profile.name,
                    avatarColor: profile.avatarColor,
                    size: 34,
                    onTap: widget.onAvatarTap,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
