import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/ui/common/updates/update_notice_modal.dart';
import 'package:axis/ui/common/updates/update_log_modal.dart';

/// Cyber-styled software update and telemetry card for the Me Screen.
class MeUpdateSection extends StatefulWidget {
  const MeUpdateSection({super.key, this.updateService});

  final AppUpdateService? updateService;

  @override
  State<MeUpdateSection> createState() => _MeUpdateSectionState();
}

class _MeUpdateSectionState extends State<MeUpdateSection> {
  late final AppUpdateService _service;
  String _versionStr = '1.2.0';
  int _buildNumber = 12;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _service = widget.updateService ?? AppUpdateService();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final ver = await _service.getInstalledVersion();
    if (mounted) {
      setState(() {
        _versionStr = '${ver.major}.${ver.minor}.${ver.patch}';
        _buildNumber = ver.buildNumber;
      });
    }
  }

  Future<void> _handleCheckForUpdates() async {
    setState(() => _isChecking = true);
    final isAr = context.isArabic;

    try {
      final update = await _service.checkForUpdate(force: true);
      if (!mounted) return;

      setState(() => _isChecking = false);

      if (update != null) {
        UpdateNoticeModal.show(
          context,
          updateInfo: update,
          currentVersion: _versionStr,
          updateService: _service,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AxisColors.surfaceLowest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AxisColors.tertiary, width: 1),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AxisColors.tertiary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr
                        ? 'تطبيق Axis محدّث إلى أحدث إصدار (v$_versionStr)'
                        : 'Axis is up to date (v$_versionStr)',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textHigh,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AxisColors.surfaceLowest,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AxisColors.priorityHigh, width: 1),
          ),
          content: Text(
            isAr ? 'تعذر التحقق من التحديثات' : 'Unable to check for updates',
            style: GoogleFonts.spaceGrotesk(color: AxisColors.priorityHigh, fontSize: 12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isArabic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          UpdateLogModal.show(
            context,
            currentVersion: _versionStr,
            buildNumber: _buildNumber,
            onCheckForUpdates: _handleCheckForUpdates,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AxisColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AxisColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isAr ? 'إصدار النظام والتحديثات' : 'SYSTEM VERSION & UPDATES',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AxisColors.textHigh,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '↗',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                color: AxisColors.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'v$_versionStr+build.$_buildNumber • ${isAr ? 'اضغط لعرض السجل' : 'Tap for update log'}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            color: AxisColors.textDim,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Check for updates button
                  InkWell(
                    key: const ValueKey('me_check_for_updates_button'),
                    onTap: _isChecking ? null : _handleCheckForUpdates,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: _isChecking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AxisColors.primarySoft,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded, size: 14, color: AxisColors.primarySoft),
                                const SizedBox(width: 6),
                                Text(
                                  isAr ? 'فحص التحديثات' : 'Check Updates',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.primarySoft,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
