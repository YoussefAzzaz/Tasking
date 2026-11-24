import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Cyber-styled system update log dialog presenting all enhancements,
/// fixes, and features completed and active in the current version.
class UpdateLogModal extends StatelessWidget {
  const UpdateLogModal({
    super.key,
    this.currentVersion = '1.3.1',
    this.buildNumber = 26,
    this.onCheckForUpdates,
  });

  final String currentVersion;
  final int buildNumber;
  final VoidCallback? onCheckForUpdates;

  static Future<void> show(
    BuildContext context, {
    String currentVersion = '1.3.1',
    int buildNumber = 26,
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
        icon: Icons.wifi_tethering_rounded,
        color: Color(0xFF10B981), // Emerald
        titleEn: 'Reliability & Widget Fixes (v1.3.1)',
        titleAr: 'إصلاحات الموثوقية والودجات (v1.3.1)',
        items: [
          _UpdateItem(
            titleEn: 'Wi-Fi OTA Update Downloader & Timeout Recovery',
            titleAr: 'إصلاح تحميل التحديثات عبر الواي فاي',
            descEn: 'Switched Android update checks and APK downloads to native OS active-network HTTP connections with read timeouts so Wi-Fi downloads never hang.',
            descAr: 'اعتماد اتصال الشبكة النشطة لنظام أندرويد في فحص وتحميل التحديثات مع مهلة للانقطاع لمنع التوقف أثناء التحميل عبر الواي فاي.',
          ),
          _UpdateItem(
            titleEn: 'Prayer Widget Direct Home Launch',
            titleAr: 'إصلاح فتح ودجت مواقيت الصلاة',
            descEn: 'Fixed prayer widget tap URI and added /prayers router guard so tapping always lands smoothly on the main Today screen.',
            descAr: 'إصلاح رابط ودجت مواقيت الصلاة وحماية مسار التوجيه ليفتح التطبيق مباشرة على الشاشة الرئيسية دون أخطاء.',
          ),
        ],
      ),
      _UpdateCategory(
        icon: Icons.widgets_rounded,
        color: Color(0xFF00E5FF), // Electric Cyan
        titleEn: 'Home Screen Widgets & UX (v1.3.0)',
        titleAr: 'ودجات الشاشة الرئيسية وتجربة الاستخدام (v1.3.0)',
        items: [
          _UpdateItem(
            titleEn: 'Horizontal Arabic Prayer Times Widget (4×1)',
            titleAr: 'ودجت مواقيت الصلاة الأفقي بالعربية (4×1)',
            descEn: 'Sorted left-to-right starting with Fajr, English date alongside Arabic Hijri date, separated Chourok time, active prayer glow, and live next-prayer timer.',
            descAr: 'ترتيب الصلوات من اليسار لليمين بدءاً بالفجر، عرض التاريخ الميلادي بالإنجليزية والتاريخ الهجري بالعربية مع فصل وقت الشروق ومؤقت الصلاة القادمة.',
          ),
          _UpdateItem(
            titleEn: 'Instant Widget App Launch & Direct Habits Routing',
            titleAr: 'دخول فوري من الودجت وفتح صفحة العادات مباشرة',
            descEn: 'Bypassed splash delay when launching from home screen widgets and enabled direct navigation to Habits.',
            descAr: 'تسريع الدخول من ودجات الشاشة الرئيسية والانتقال الفوري إلى صفحة العادات عند النقر على ودجت العادات.',
          ),
          _UpdateItem(
            titleEn: 'Spacious Me Screen & Version Cadence',
            titleAr: 'تحسين تصميم شاشة الملف الشخصي وسجل التحديثات',
            descEn: 'Relocated Sign Out to the top bar, moved cloud sync status under Profile, and redesigned Update Log modals with clean version-only badges.',
            descAr: 'نقل زر تسجيل الخروج للشريط العلوي وحالة السحابة أسفل الملف الشخصي، مع إعادة تنسيق بطاقة وقائمة التحديثات بوضوح أكبر.',
          ),
        ],
      ),
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
        titleEn: 'Daily Journal & Desktop Refinements',
        titleAr: 'تصميم اليوميات وتحسينات سطح المكتب',
        items: [
          _UpdateItem(
            titleEn: 'Clutter-Free Mindful Journal & Compact Desktop Card',
            titleAr: 'بطاقة يوميات هادئة وتحسينات بطاقة التحديثات',
            descEn: 'Streamlined daily reflection card, aligned desktop release placement, and reliable GitHub redirect OTA downloads.',
            descAr: 'تبسيط بطاقة اليوميات لتكون مريحة للعين، وتحسين ترتيب بطاقات سطح المكتب وتدفق التحديثات التلقائية.',
          ),
        ],
      ),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
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
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AxisColors.borderSubtle)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AxisColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.history_rounded, color: AxisColors.primarySoft, size: 19),
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
                                isAr ? 'سجل التحديثات' : 'UPDATE LOG',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: isAr ? 0.0 : 0.8,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AxisColors.tertiary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AxisColors.tertiary.withValues(alpha: 0.38)),
                              ),
                              child: Text(
                                'v$currentVersion',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: AxisColors.tertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isAr
                              ? 'التحسينات والميزات المفعلة في الإصدار الحالي'
                              : 'Improvements & features active in this release',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ──────────────────────────────────────
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, catIndex) {
                  final cat = categories[catIndex];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLowest.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cat.color.withValues(alpha: 0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(cat.icon, size: 16, color: cat.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isAr ? cat.titleAr : cat.titleEn,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cat.color,
                                  letterSpacing: isAr ? 0.0 : 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...cat.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: AxisColors.tertiary.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAr ? item.titleAr : item.titleEn,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AxisColors.textHigh,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isAr ? item.descAr : item.descEn,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 11,
                                          color: AxisColors.textMuted,
                                          height: 1.4,
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

            // ── Footer (Mobile-First, Zero Cramping) ───────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AxisColors.borderSubtle)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: AxisColors.tertiary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isAr
                              ? 'الإصدار الحالي مثبت ومفعّل (v$currentVersion)'
                              : 'Current version active & verified (v$currentVersion)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: AxisColors.textDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onCheckForUpdates != null) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onCheckForUpdates!();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AxisColors.primarySoft,
                              backgroundColor: AxisColors.primary.withValues(alpha: 0.1),
                              side: BorderSide(color: AxisColors.primary.withValues(alpha: 0.35)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 15),
                            label: Text(
                              isAr ? 'فحص التحديثات' : 'Check Updates',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AxisColors.surfaceHigh,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            isAr ? 'إغلاق' : 'Close',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
