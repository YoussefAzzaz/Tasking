import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/mastery_badge_repository.dart';
import '../../../me/mastery_badges_screen.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';
import 'desktop_badge_card.dart';

/// Desktop card displaying the redesigned mastery badges section in the profile.
class DesktopMasteryBadgesCard extends StatefulWidget {
  const DesktopMasteryBadgesCard({super.key});

  @override
  State<DesktopMasteryBadgesCard> createState() => _DesktopMasteryBadgesCardState();
}

class _DesktopMasteryBadgesCardState extends State<DesktopMasteryBadgesCard> {
  final ScrollController _badgesScrollController = ScrollController();
  BadgeCategory _selectedCategory = BadgeCategory.all;
  bool _unlockedOnly = false;

  @override
  void dispose() {
    _badgesScrollController.dispose();
    super.dispose();
  }

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
        final allBadges = snapshot.data ?? [];
        final unlockedCount = allBadges.where((b) => b.isUnlocked).length;
        final totalCount = allBadges.isNotEmpty ? allBadges.length : 50;

        final filtered = allBadges.where((b) {
          if (_selectedCategory != BadgeCategory.all && b.categoryEnum != _selectedCategory) {
            return false;
          }
          if (_unlockedOnly && !b.isUnlocked) {
            return false;
          }
          return true;
        }).toList();

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isAr ? 'أوسمة إتقان المشغل' : 'OPERATOR MASTERY BADGES',
                subtitle: isAr
                    ? '50 إنجازاً تشغيلياً مقسماً لمستويات عبر العادات والمهام'
                    : '50 tiered operational milestones across routines and deliverables',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TelemetryChip(
                      label: isAr ? '$unlockedCount / $totalCount مفتوحة' : '$unlockedCount / $totalCount UNLOCKED',
                      dotColor: AxisColors.warning,
                      color: AxisColors.warning,
                    ),
                    const SizedBox(width: 8),
                    GhostButton(
                      label: isAr ? 'المعرض ↗' : 'Showroom ↗',
                      height: 26,
                      onPressed: () => _openMasteryBadgesModal(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Category Filter Pills & Unlocked Toggle
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in BadgeCategory.values) ...[
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _selectedCategory == cat
                                  ? cat.color.withValues(alpha: 0.20)
                                  : AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _selectedCategory == cat
                                    ? cat.color.withValues(alpha: 0.55)
                                    : AxisColors.borderSubtle,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  cat.icon,
                                  size: 11,
                                  color: _selectedCategory == cat ? cat.color : AxisColors.textDim,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  cat.localizedLabel(isAr),
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: _selectedCategory == cat ? FontWeight.w700 : FontWeight.w500,
                                    color: _selectedCategory == cat ? AxisColors.textHigh : AxisColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    // Unlocked Only Toggle
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _unlockedOnly = !_unlockedOnly),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _unlockedOnly
                              ? AxisColors.primary.withValues(alpha: 0.20)
                              : AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _unlockedOnly ? AxisColors.primary : AxisColors.borderSubtle,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _unlockedOnly ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                              size: 11,
                              color: _unlockedOnly ? AxisColors.primary : AxisColors.textDim,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAr ? 'مفتوحة فقط' : 'Unlocked Only',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: _unlockedOnly ? FontWeight.w700 : FontWeight.w500,
                                color: _unlockedOnly ? AxisColors.textHigh : AxisColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Badges Grid
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      isAr ? 'لا توجد شارات تطابق هذا الفلتر.' : 'No badges match this filter.',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 270,
                  child: Scrollbar(
                    controller: _badgesScrollController,
                    thumbVisibility: true,
                    child: GridView.builder(
                      controller: _badgesScrollController,
                      primary: false,
                      padding: const EdgeInsetsDirectional.only(end: 8.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 74,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final badge = filtered[index];
                        return DesktopBadgeCard(
                          badge: badge,
                          onTap: () => DesktopBadgeDetailDialog.show(context, badge: badge),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
