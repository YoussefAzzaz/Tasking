import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/ui/common/updates/update_notice_modal.dart';
import 'package:axis/ui/common/updates/update_log_modal.dart';

/// Cyber-styled software update and telemetry card for the Me Screen.
/// Redesigned into an airy two-tier layout showing version only (without build numbers)
/// and dedicated action pills for Update Log & Check Updates.
class MeUpdateSection extends StatefulWidget {
  const MeUpdateSection({super.key, this.updateService});

  final AppUpdateService? updateService;

  @override
  State<MeUpdateSection> createState() => _MeUpdateSectionState();
}

class _MeUpdateSectionState extends State<MeUpdateSection> {
  late final AppUpdateService _service;
  String _versionStr = '1.3.1';
  int _buildNumber = 26;
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
      } else if (_service.lastErrorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AxisColors.surfaceLowest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AxisColors.priorityHigh, width: 1),
            ),
            content: Text(
              isAr ? 'تعذر التحقق من التحديثات على الشبكة الحالية' : 'Unable to check for updates on current network',
              style: GoogleFonts.spaceGrotesk(color: AxisColors.priorityHigh, fontSize: 12),
            ),
          ),
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

  void _openUpdateLog() {
    UpdateLogModal.show(
      context,
      currentVersion: _versionStr,
      buildNumber: _buildNumber,
      onCheckForUpdates: _handleCheckForUpdates,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isArabic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tier 1: Spacious Icon + Title + Version Badge
            InkWell(
              onTap: _openUpdateLog,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AxisColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AxisColors.primarySoft,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'إصدار النظام والتحديثات' : 'SYSTEM VERSION & UPDATES',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: isAr ? 0.0 : 0.7,
                            color: AxisColors.textHigh,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isAr
                              ? 'استعراض الميزات أو التحقق من الإصدارات'
                              : 'View changelog or check releases',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: AxisColors.textDim,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AxisColors.tertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AxisColors.tertiary.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'v$_versionStr',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Divider(color: AxisColors.borderSubtle, height: 1),
            const SizedBox(height: 14),

            // Tier 2: Uncrowded, Balanced Two-Button Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('me_view_update_log_button'),
                    onPressed: _openUpdateLog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AxisColors.tertiary,
                      backgroundColor: AxisColors.tertiary.withValues(alpha: 0.08),
                      side: BorderSide(color: AxisColors.tertiary.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 15),
                    label: Text(
                      isAr ? 'سجل التحديثات' : 'Update Log',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const ValueKey('me_check_for_updates_button'),
                    onPressed: _isChecking ? null : _handleCheckForUpdates,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AxisColors.primary.withValues(alpha: 0.18),
                      foregroundColor: AxisColors.primarySoft,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AxisColors.primary.withValues(alpha: 0.4)),
                      ),
                    ),
                    icon: _isChecking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AxisColors.primarySoft,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 15),
                    label: Text(
                      isAr ? 'فحص التحديثات' : 'Check Updates',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
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
    );
  }
}
