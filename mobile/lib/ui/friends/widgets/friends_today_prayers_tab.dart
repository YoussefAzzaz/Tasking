import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/network_service.dart';

import 'my_personal_checklist_card.dart';
import 'companion_checklist_card.dart';

/// Tab presenting today's prayer and habit progress with separation between current user and companions.
class FriendsTodayPrayersTab extends StatelessWidget {
  final ScrollController? scrollController;
  final VoidCallback onAddCompanion;

  const FriendsTodayPrayersTab({
    super.key,
    this.scrollController,
    required this.onAddCompanion,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final friendRepo = FriendRepository();
    final prayerService = PrayerTimeService();

    return RefreshIndicator(
      onRefresh: () async {
        await friendRepo.syncAllFriendData();
      },
      color: AxisColors.primary,
      backgroundColor: AxisColors.surfaceLow,
      child: ListView(
        controller: scrollController,
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AxisColors.primary.withValues(alpha: 0.16),
                  AxisColors.tertiary.withValues(alpha: 0.08),
                  AxisColors.surfaceLowest,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AxisColors.primary.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.primary.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AxisColors.tertiary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: AxisColors.tertiary.withValues(alpha: 0.5)),
                  ),
                  child: const Center(
                    child: Icon(Icons.mosque_rounded, color: AxisColors.tertiaryBright, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mutualPrayerAccountability.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AxisColors.tertiaryBright,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.todayPrayerSub,
                        style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textMuted, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          StreamBuilder<List<DailyPrayerStatus>>(
            stream: friendRepo.watchTodayChecklist(),
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

              if (isLoading) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft),
                    ),
                  ),
                );
              }

              if (list.isEmpty) {
                return _buildEmptyState(
                  context: context,
                  title: l10n.noCompanionsYet,
                  subtitle: l10n.noCompanionsDesc,
                  actionLabel: l10n.addCompanion,
                  onAction: onAddCompanion,
                );
              }

              DailyPrayerStatus? myStatus;
              final companionStatuses = <DailyPrayerStatus>[];
              final myUid = friendRepo.currentUserId;

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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (myStatus != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, size: 16, color: AxisColors.primarySoft),
                          const SizedBox(width: 7),
                          Text(
                            l10n.yourChecklist.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: AxisColors.primarySoft,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${myStatus.completedCount}/5',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AxisColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MyPersonalChecklistCard(
                      status: myStatus,
                      prayerService: prayerService,
                    ),
                    const SizedBox(height: 18),
                  ],

                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, size: 16, color: AxisColors.secondary),
                        const SizedBox(width: 7),
                        Text(
                          l10n.companionsAccountability.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AxisColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AxisColors.secondary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AxisColors.secondary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${companionStatuses.length}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AxisColors.secondarySoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: NetworkService().isOnlineNotifier,
                    builder: (context, isOnline, _) {
                      if (!isOnline) {
                        return _buildOfflineState(
                          context: context,
                          l10n: l10n,
                        );
                      }
                      if (companionStatuses.isEmpty) {
                        return _buildEmptyState(
                          context: context,
                          title: l10n.noCompanionsYet,
                          subtitle: l10n.noCompanionsDesc,
                          actionLabel: l10n.addCompanion,
                          onAction: onAddCompanion,
                        );
                      }
                      return Column(
                        children: companionStatuses
                            .map((status) => CompanionChecklistCard(
                                  status: status,
                                  friendRepo: friendRepo,
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState({
    required BuildContext context,
    required AppLocalizations l10n,
  }) {
    final isArabic = l10n.isArabic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              shape: BoxShape.circle,
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: const Center(
              child: Icon(Icons.wifi_off_rounded, size: 28, color: AxisColors.warning),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? 'بيانات المرافقين متاحة عند الاتصال' : 'Companion Data Available Online',
            style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'متابعة صلوات المرافقين تتطلب اتصالاً نشطاً بالإنترنت. ستظهر البيانات تلقائياً بمجرد إعادة الاتصال.'
                : 'Live prayer accountability with your companions requires an active internet connection. Data will appear automatically once back online.',
            style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textMuted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              shape: BoxShape.circle,
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: const Center(
              child: Icon(Icons.people_outline_rounded, size: 28, color: AxisColors.textDim),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AxisColors.textHigh), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AxisColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: Text(actionLabel, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
