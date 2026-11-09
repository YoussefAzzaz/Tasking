import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Telemetry card showing the offline encrypted vault synchronization progress,
/// luminous animated progress bar, and latency/state/nodes diagnostics columns.
class VaultSyncTelemetryCard extends StatelessWidget {
  final Animation<double> progressAnim;

  const VaultSyncTelemetryCard({
    super.key,
    required this.progressAnim,
  });

  Widget _buildTelemetryColumn({
    required String label,
    required String value,
    required Color valueColor,
    required CrossAxisAlignment align,
    bool isArabic = false,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: isArabic ? 0.0 : 1.2,
            color: AxisColors.textDim,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: isArabic ? 0.0 : 0.4,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return AnimatedBuilder(
      animation: progressAnim,
      builder: (context, child) {
        final pct = (progressAnim.value * 100).toInt();
        return Semantics(
          label: isArabic
              ? 'تقدم مزامنة الخزينة: $pct بالمائة'
              : 'Vault synchronization progress: $pct percent',
          value: '$pct%',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow.withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header Row with robust flexible text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_clock_outlined,
                            size: 14,
                            color: Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isArabic
                                  ? 'مزامنة الخزينة غير المتصلة المشفرة'
                                  : 'SYNCHRONIZING SECURE OFFLINE VAULT',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: isArabic ? 0.0 : 0.6,
                                color: AxisColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      pct >= 100
                          ? (isArabic ? 'جاهز 100%' : '100% READY')
                          : '$pct%',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: const Color(0xFF8ED5FF),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Luminous Progress Bar
                Container(
                  height: 4.5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          width: constraints.maxWidth * progressAnim.value,
                          height: 4.5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF38BDF8),
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF38BDF8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Telemetry Grid: 3 columns
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTelemetryColumn(
                        label: isArabic ? 'الاستجابة' : 'LATENCY',
                        value: '0.8ms',
                        valueColor: AxisColors.textHigh,
                        align: CrossAxisAlignment.start,
                        isArabic: isArabic,
                      ),
                      _buildTelemetryColumn(
                        label: isArabic ? 'الحالة' : 'STATE',
                        value: isArabic ? 'مشفر' : 'ENCRYPTED',
                        valueColor: const Color(0xFF38BDF8),
                        align: CrossAxisAlignment.center,
                        isArabic: isArabic,
                      ),
                      _buildTelemetryColumn(
                        label: isArabic ? 'العقد' : 'NODES',
                        value: isArabic ? '64 نشطة' : '64 ACTIVE',
                        valueColor: const Color(0xFF818CF8),
                        align: CrossAxisAlignment.end,
                        isArabic: isArabic,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

