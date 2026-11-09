import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/mastery_badge_repository.dart';
import '../../../me/mastery_badges_screen.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Desktop card triggering the full-screen Mastery Badges modal dialog.
class DesktopMasteryBadgesCard extends StatelessWidget {
  const DesktopMasteryBadgesCard({super.key});

  void _openMasteryBadgesModal(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Container(
          width: 960,
          height: 720,
          decoration: BoxDecoration(
            color: AxisColors.canvasBase,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AxisColors.borderGlass2, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AxisColors.borderSubtle)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: AxisColors.secondary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          isAr
                              ? 'غرفة جوائز وأوسمة المشغل المتميز'
                              : 'MASTER OPERATOR TROPHY ROOM & BADGES',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AxisColors.textHigh,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                      tooltip: isAr ? 'إغلاق' : 'Close',
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: MasteryBadgesScreen(),
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
    final isAr = AppLocalizations.of(context).isArabic;
    return FutureBuilder<List<MasteryBadgeData>>(
      future: MasteryBadgeRepository().getMasteryBadges(),
      builder: (context, snapshot) {
        final badges = snapshot.data ?? [];
        final unlocked = badges.where((b) => b.isUnlocked).length;
        final total = badges.isNotEmpty ? badges.length : 50;

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isAr ? 'أوسمة إتقان المشغل' : 'OPERATOR MASTERY BADGES',
                subtitle: isAr
                    ? '50 إنجازاً تشغيلياً مقسماً لمستويات عبر العادات والمهام'
                    : '50 tiered operational milestones across routines and deliverables',
                trailing: TelemetryChip(
                  label: isAr ? '$unlocked / $total مفتوحة' : '$unlocked / $total UNLOCKED',
                  dotColor: AxisColors.warning,
                  color: AxisColors.warning,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(8),
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
                                  isAr ? 'معرض الجوائز' : 'TROPHY SHOWROOM',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: AxisColors.textHigh,
                                  ),
                                ),
                                Text(
                                  isAr
                                      ? 'استكشف شارات المستويات للعادات، والتركيز العميق، والمواظبة على الصلاة والمهام'
                                      : 'Explore tier badges for habits, deep focus, prayer consistency & tasks',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AccentButton(
                    label: isAr ? 'فتح الشارات ↗' : 'Open Badges ↗',
                    height: 38,
                    onPressed: () => _openMasteryBadgesModal(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

