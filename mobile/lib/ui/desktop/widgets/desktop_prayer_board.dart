import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'package:axis/ui/friends/widgets/companion_profile_modal.dart';
import '../widgets/desktop_card.dart';
import '../widgets/section_header.dart';
import '../widgets/ghost_button.dart';

/// Desktop panel for tracking prayers & habits with separation between user and companions.
class DesktopPrayerBoard extends StatefulWidget {
  const DesktopPrayerBoard({super.key});

  @override
  State<DesktopPrayerBoard> createState() => _DesktopPrayerBoardState();
}

class _DesktopPrayerBoardState extends State<DesktopPrayerBoard> {
  final _friendRepo = FriendRepository();
  final _prayerService = PrayerTimeService();
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _friendRepo.syncAllFriendData();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AxisSnackBar.show(
          context,
          message: l10n.isArabic ? 'تم تحديث لوحة الصحبة بنجاح' : 'Companions board refreshed',
          icon: Icons.cloud_done_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isArabic ? 'لوحة الصلوات والعادات اليومية' : 'TODAY\'S PRAYER & HABIT BOARD',
            trailing: GhostButton(
              label: isArabic ? 'تحديث' : 'Refresh',
              icon: Icons.refresh_rounded,
              height: 26,
              onPressed: _handleRefresh,
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
                          Text(l10n.noCompanionsYet, style: AxisFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.bold, color: AxisColors.textHigh)),
                          const SizedBox(height: 4),
                          Text(l10n.noCompanionsDesc, style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim)),
                        ],
                      ),
                    ),
                  );
                }

                DailyPrayerStatus? myStatus;
                final companionStatuses = <DailyPrayerStatus>[];
                final myUid = _friendRepo.currentUserId;

                if (list.isNotEmpty) {
                  // By architectural design, index 0 is guaranteed to be current user
                  myStatus = list.first;
                  for (int i = 1; i < list.length; i++) {
                    final s = list[i];
                    if (myUid.isNotEmpty && s.userId == myUid) {
                      myStatus = s;
                    } else {
                      companionStatuses.add(s);
                    }
                  }
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (myStatus != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, size: 14, color: AxisColors.primarySoft),
                            const SizedBox(width: 6),
                            Text(
                              l10n.yourChecklist.toUpperCase(),
                              style: AxisFonts.spaceGrotesk(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AxisColors.primarySoft),
                            ),
                            const Spacer(),
                            Text(
                              '${myStatus.completedCount}/5 ${isArabic ? "صلوات" : "prayers"}',
                              style: AxisFonts.spaceGrotesk(fontSize: 10.5, fontWeight: FontWeight.w700, color: AxisColors.tertiary),
                            ),
                          ],
                        ),
                      ),
                      _buildMyDesktopChecklistCard(myStatus, isArabic, l10n),
                      const SizedBox(height: 16),
                    ],

                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 14, color: AxisColors.secondary),
                          const SizedBox(width: 6),
                          Text(
                            l10n.companionsAccountability.toUpperCase(),
                            style: AxisFonts.spaceGrotesk(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: AxisColors.secondary),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AxisColors.secondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '${companionStatuses.length}',
                              style: AxisFonts.spaceGrotesk(fontSize: 9.5, fontWeight: FontWeight.w800, color: AxisColors.secondarySoft),
                            ),
                          ),
                        ],
                      ),
                    ),

                    ValueListenableBuilder<bool>(
                      valueListenable: NetworkService().isOnlineNotifier,
                      builder: (context, isOnline, _) {
                        if (!isOnline) {
                          return _buildDesktopOfflineState(isArabic);
                        }
                        if (companionStatuses.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  const Icon(Icons.person_add_alt_1_outlined, size: 28, color: AxisColors.textDim),
                                  const SizedBox(height: 6),
                                  Text(l10n.noCompanionsYet, style: AxisFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: AxisColors.textHigh)),
                                  const SizedBox(height: 2),
                                  Text(l10n.noCompanionsDesc, style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim)),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: companionStatuses
                              .map((st) => _buildCompanionDesktopChecklistCard(st, isArabic, l10n))
                              .toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopOfflineState(bool isArabic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              shape: BoxShape.circle,
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: const Center(
              child: Icon(Icons.wifi_off_rounded, size: 22, color: AxisColors.warning),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isArabic ? 'بيانات المرافقين متاحة عند الاتصال' : 'Companion Data Available Online',
            style: AxisFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            isArabic
                ? 'متابعة صلوات المرافقين تتطلب اتصالاً بالإنترنت. ستظهر البيانات تلقائياً بمجرد إعادة الاتصال.'
                : 'Live prayer accountability with your companions requires an active internet connection. Data will appear automatically once back online.',
            style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textMuted, height: 1.3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMyDesktopChecklistCard(DailyPrayerStatus status, bool isArabic, AppLocalizations l10n) {
    final prayers = [
      {'code': 'fajr', 'name': isArabic ? 'الفجر' : 'Fajr', 'done': status.fajr},
      {'code': 'dhuhr', 'name': isArabic ? 'الظهر' : 'Dhuhr', 'done': status.dhuhr},
      {'code': 'asr', 'name': isArabic ? 'العصر' : 'Asr', 'done': status.asr},
      {'code': 'maghrib', 'name': isArabic ? 'المغرب' : 'Maghrib', 'done': status.maghrib},
      {'code': 'isha', 'name': isArabic ? 'العشاء' : 'Isha', 'done': status.isha},
    ];

    final habitsTotal = status.habitsTotal;
    final habitsDone = status.habitsDone;
    final habitFraction = habitsTotal > 0 ? (habitsDone / habitsTotal).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AxisColors.primary.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AvatarWidget(name: status.userName, avatarColor: status.userAvatarColor, avatarUrl: status.userAvatarUrl, size: 36),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            status.userName.isNotEmpty && status.userName != 'You' ? status.userName : l10n.youLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AxisFonts.getFont('Geist', fontSize: 13, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: AxisColors.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(4)),
                          child: Text(l10n.youLabel, style: AxisFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold, color: AxisColors.primarySoft)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, size: 12, color: AxisColors.warning),
                        const SizedBox(width: 2),
                        Text(
                          '${status.streakDays}${isArabic ? " يوم متتالي" : "d streak"} · ${status.completedCount}/5 ${isArabic ? "صلوات" : "prayers"}',
                          style: AxisFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w600, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$habitsDone/$habitsTotal ${l10n.dailyHabitsCount}',
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: habitFraction >= 1.0 ? AxisColors.tertiary : AxisColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: habitFraction,
                        minHeight: 4,
                        backgroundColor: AxisColors.surfaceHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(habitFraction >= 1.0 ? AxisColors.tertiary : AxisColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: prayers.map((p) {
              final isDone = p['done'] as bool;
              final name = p['name'] as String;
              final code = p['code'] as String;

              return Expanded(
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await _prayerService.togglePrayer(code, !isDone);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isDone ? AxisColors.tertiary.withValues(alpha: 0.18) : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDone ? AxisColors.tertiary.withValues(alpha: 0.8) : AxisColors.borderSubtle.withValues(alpha: 0.5),
                        width: isDone ? 1.2 : 0.8,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 13, color: isDone ? AxisColors.tertiary : AxisColors.textDim),
                        const SizedBox(height: 2),
                        Text(name, style: AxisFonts.spaceGrotesk(fontSize: 9.5, fontWeight: isDone ? FontWeight.bold : FontWeight.w500, color: isDone ? AxisColors.textHigh : AxisColors.textDim)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanionDesktopChecklistCard(DailyPrayerStatus status, bool isArabic, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          CompanionProfileModal.showCompanionDialog(context, status);
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            AvatarWidget(
              name: status.userName,
              avatarColor: status.userAvatarColor,
              avatarUrl: status.userAvatarUrl,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          status.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AxisFonts.getFont('Geist', fontSize: 13, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AxisColors.primarySoft.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'LVL ${status.level}',
                          style: AxisFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.bold, color: AxisColors.primarySoft),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isArabic ? 'المستوى ${status.level}' : 'Level ${status.level}',
                    style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AxisColors.textDim),
          ],
        ),
      ),
    );
  }
}

