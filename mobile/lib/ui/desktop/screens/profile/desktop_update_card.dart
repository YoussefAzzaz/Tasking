import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/updates/app_update_service.dart';
import '../../../common/updates/update_notice_modal.dart';

/// Cyber-styled software update telemetry card for Desktop Profile & Settings.
class DesktopUpdateCard extends StatefulWidget {
  const DesktopUpdateCard({super.key, this.updateService});

  final AppUpdateService? updateService;

  @override
  State<DesktopUpdateCard> createState() => _DesktopUpdateCardState();
}

class _DesktopUpdateCardState extends State<DesktopUpdateCard> {
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
                        : 'Axis Desktop is up to date (v$_versionStr)',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isArabic;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AxisColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update_rounded,
              color: AxisColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'إصدار سطح المكتب والتحديثات' : 'DESKTOP RELEASE & SYSTEM UPDATES',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AxisColors.textHigh,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Axis System Engine v$_versionStr (Build $_buildNumber) • Platform: ${_service.currentPlatform.toUpperCase()}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AxisColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Check for Updates Button
          InkWell(
            key: const ValueKey('desktop_check_for_updates_button'),
            onTap: _isChecking ? null : _handleCheckForUpdates,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AxisColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.primary.withValues(alpha: 0.4)),
              ),
              child: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AxisColors.primarySoft,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, size: 16, color: AxisColors.primarySoft),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'فحص التحديثات' : 'Check for Updates',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
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
    );
  }
}
