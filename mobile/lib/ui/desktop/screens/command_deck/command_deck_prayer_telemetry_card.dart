import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/prayer_time_service.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/progress_gauge.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Telemetry card showing the daily prayer obligations and progress gauge.
class CommandDeckPrayerTelemetryCard extends StatelessWidget {
  const CommandDeckPrayerTelemetryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isArabic ? 'قياسات الصلوات' : 'PRAYER TELEMETRY',
          ),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<List<Prayer>>(
              stream: PrayerTimeService().watchPrayers(),
              builder: (context, snapshot) {
                final prayers = snapshot.data ?? [];
                final doneCount = prayers.where((p) => p.isDone).length;
                final totalCount = prayers.isNotEmpty ? prayers.length : 5;
                final progress = (doneCount / totalCount).clamp(0.0, 1.0);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: prayers.length,
                        itemBuilder: (context, index) {
                          final prayer = prayers[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                DesktopCheckbox(
                                  value: prayer.isDone,
                                  color: AxisColors.tertiary,
                                  onChanged: (val) {
                                    PrayerTimeService().togglePrayer(prayer.id, val);
                                  },
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context).prayerName(prayer.name),
                                    style: GoogleFonts.getFont(
                                      'Geist',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: prayer.isDone ? AxisColors.textDim : AxisColors.textHigh,
                                    ),
                                  ),
                                ),
                                Text(
                                  prayer.time,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    color: AxisColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TelemetryChip(
                                  label: prayer.isDone
                                      ? (isArabic ? 'تم' : 'Done')
                                      : (isArabic ? 'قادمة' : 'Upcoming'),
                                  color: prayer.isDone ? AxisColors.tertiary : AxisColors.textDim,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProgressGauge(
                      value: progress,
                      label: isArabic
                          ? 'الفرائض: $doneCount/$totalCount (${(progress * 100).toInt()}٪)'
                          : 'OBLIGATIONS: $doneCount/$totalCount (${(progress * 100).toInt()}%)',
                      color: AxisColors.tertiary,
                      height: 5.0,
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
}
