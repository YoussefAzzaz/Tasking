import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Cyber-styled system update log dialog presenting all enhancements,
/// fixes, and features completed and active in the current version.
class UpdateLogModal extends StatelessWidget {
  const UpdateLogModal({
    super.key,
    this.currentVersion = '1.2.9',
    this.buildNumber = 23,
    this.onCheckForUpdates,
  });

  final String currentVersion;
  final int buildNumber;
  final VoidCallback? onCheckForUpdates;

  static Future<void> show(
    BuildContext context, {
    String currentVersion = '1.2.9',
    int buildNumber = 23,
    VoidCallback? onCheckForUpdates,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdateLogModal(
        currentVersion: currentVersion,
        buildNumber: buildNumber,
        onCheckForUpdates: onCheckForUpdates,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isArabic;

    const categories = <_UpdateCategory>[
      _UpdateCategory(
        icon: Icons.mosque_rounded,
        color: Color(0xFF06B6D4), // Cyan
        titleEn: 'Prayer & Adhan Intelligence',
        titleAr: 'نظام الأذان وتنبيهات الصلاة',
        items: [
          _UpdateItem(
            titleEn: 'Single-Trigger Fajr Wake-Up',
            titleAr: 'تنبيه الفجر الموحد للاستيقاظ',
            descEn: 'Removed redundant duplicate Fajr alarms. Fajr triggers as one authoritative, unmissable wake-up alarm.',
            descAr: 'إلغاء التنبيهات المكررة لصلاة الفجر، وتوحيدها في تنبيه استيقاظ رئيسي واحد لا يمكن تفويته.',
          ),
          _UpdateItem(
            titleEn: 'Anti-Sleep Fajr Cognitive Challenge',
            titleAr: 'تحدي الاستيقاظ الذهني لصلاة الفجر',
            descEn: 'Fajr alarm cannot be directly dismissed. Requires solving a mental arithmetic challenge to stop ringing.',
            descAr: 'لا يمكن إغلاق منبه الفجر بضغطة واحدة عابرة، بل يتطلب حل تحدٍ حسابي ذهني لإيقاف الرنين والتأكد من الاستيقاظ.',
          ),
          _UpdateItem(
            titleEn: 'Isha & Daily Prayers Ringing Dedup',
            titleAr: 'إصلاح التكرار والازدواجية في صلاة العشاء',
            descEn: 'Resolved dual audio playback and overlapping notifications across all prayer times.',
            descAr: 'إصلاح ازدواجية رنين الأذان وإلغاء تكرار الإشعارات المتزامنة في صلاة العشاء وبقية الصلوات.',
          ),
        ],
      ),
      _UpdateCategory(
        icon: Icons.calendar_month_rounded,
        color: Color(0xFF3B82F6), // Blue
        titleEn: 'Calendar Visual Clarity',
        titleAr: 'وضوح وتمييز ألوان التقويم',
        items: [
          _UpdateItem(
            titleEn: 'Dedicated Blue Color for Habits',
            titleAr: 'لون أزرق مميز لروتين العادات اليومية',
            descEn: 'Habits are now rendered in distinctive cyber blue to eliminate confusion with green completed tasks.',
            descAr: 'تلوين العادات باللون الأزرق المميز لمنع اللبس والخلط بينها وبين المهام المكتملة ذات اللون الأخضر.',
          ),
          _UpdateItem(
            titleEn: 'Unique Colors for Each Daily Prayer',
            titleAr: 'ألوان فريدة ومستقلة لكل صلاة',
            descEn: 'Fajr (Dawn Cyan), Dhuhr (Solar Gold), Asr (Sunset Orange), Maghrib (Dusk Crimson), and Isha (Night Violet).',
            descAr: 'الفجر (سماوي الفجر)، الظهر (ذهبي شمسي)، العصر (برتقالي الغروب)، المغرب (قرمزي الشفق)، والعشاء (بنفسجي الليل).',
          ),
        ],
      ),
      _UpdateCategory(
        icon: Icons.auto_stories_rounded,
        color: Color(0xFF10B981), // Emerald
        titleEn: 'Daily Journal Serenity',
        titleAr: 'تصميم مريح وهادئ لليوميات اليومية',
        items: [
          _UpdateItem(
            titleEn: 'Clutter-Free Mindful Dashboard Card',
            titleAr: 'بطاقة يوميات هادئة وخالية من التشتت',
            descEn: 'Streamlined design removing visual noise and multi-layered buttons in favor of a relaxing, inviting reflection space.',
            descAr: 'إعادة تصميم بطاقة اليوميات لتكون هادئة ومريحة للعين وخالية من الضجيج والأزرار المتراكمة، مع الحفاظ على جاذبيتها.',
          ),
        ],
      ),
      _UpdateCategory(
        icon: Icons.desktop_mac_rounded,
        color: Color(0xFF8B5CF6), // Violet
        titleEn: 'Desktop Profile Refinements',
        titleAr: 'تحسينات واجهة سطح المكتب',
        items: [
          _UpdateItem(
            titleEn: 'Compact Update Telemetry Placement',
            titleAr: 'إعادة تنظيم بطاقة الإصدار والتحديثات',
            descEn: 'Moved the update card directly alongside Mastery Badges, matching the task tags & labels column width.',
            descAr: 'نقل بطاقة التحديثات بجانب بطاقة أوسمة الإتقان وجعلها بنفس عرض بطاقة وسوم وعلامات المهام استغلالاً للمساحة.',
          ),
        ],
      ),
      _UpdateCategory(
        icon: Icons.system_update_rounded,
        color: Color(0xFFF59E0B), // Amber
        titleEn: 'Over-The-Air Update Engine',
        titleAr: 'محرك التحديثات الفورية والتحميل',
        items: [
          _UpdateItem(
            titleEn: 'HTTP 302 Redirect Streaming Fix',
            titleAr: 'إصلاح تدفق التحميل والتوجيه السحابي',
            descEn: 'Resolved 0B/0B download stalls from GitHub Releases with automatic cloud redirect extraction and direct browser fallback.',
            descAr: 'إصلاح توقف تحميل حزمة التحديث عند 0 بايت عبر معالجة التوجيه السحابي التلقائي وإضافة خيار التحميل من المتصفح.',
          ),
        ],
      ),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        decoration: BoxDecoration(
          color: const Color(0xFF090E17),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AxisColors.borderSubtle, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AxisColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AxisColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.history_rounded, color: AxisColors.primarySoft, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isAr ? 'سجل تحديثات النظام' : 'SYSTEM UPDATE LOG',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AxisColors.textHigh,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AxisColors.tertiary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AxisColors.tertiary.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'v$currentVersion+$buildNumber',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AxisColors.tertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAr
                              ? 'جميع التحسينات والميزات المكتملة والمفعلة في هذا الإصدار'
                              : 'All completed updates & enhancements active in this release',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: AxisColors.textDim,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ──────────────────────────────────────
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(18),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, catIndex) {
                  final cat = categories[catIndex];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLowest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cat.color.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Header
                        Row(
                          children: [
                            Icon(cat.icon, size: 16, color: cat.color),
                            const SizedBox(width: 8),
                            Text(
                              isAr ? cat.titleAr : cat.titleEn,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: cat.color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Category Items
                        ...cat.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AxisColors.tertiary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AxisColors.tertiary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    isAr ? 'مكتمل ✓' : 'DONE ✓',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: AxisColors.tertiary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAr ? item.titleAr : item.titleEn,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: AxisColors.textHigh,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isAr ? item.descAr : item.descEn,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 10.5,
                                          color: AxisColors.textMuted,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Footer ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AxisColors.borderSubtle)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: AxisColors.tertiary),
                      const SizedBox(width: 6),
                      Text(
                        isAr ? 'الإصدار الحالي مثبت ومفعّل' : 'Current build active & verified',
                        style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onCheckForUpdates != null)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onCheckForUpdates!();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: AxisColors.primarySoft),
                          label: Text(
                            isAr ? 'فحص التحديثات' : 'Check for Updates',
                            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: AxisColors.primarySoft),
                          ),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AxisColors.surfaceHigh,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          isAr ? 'إغلاق' : 'Close',
                          style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateCategory {
  final IconData icon;
  final Color color;
  final String titleEn;
  final String titleAr;
  final List<_UpdateItem> items;

  const _UpdateCategory({
    required this.icon,
    required this.color,
    required this.titleEn,
    required this.titleAr,
    required this.items,
  });
}

class _UpdateItem {
  final String titleEn;
  final String titleAr;
  final String descEn;
  final String descAr;

  const _UpdateItem({
    required this.titleEn,
    required this.titleAr,
    required this.descEn,
    required this.descAr,
  });
}
