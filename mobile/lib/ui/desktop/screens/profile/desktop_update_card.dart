import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/updates/app_update_service.dart';
import '../../../common/updates/update_notice_modal.dart';
import '../../../common/updates/update_log_modal.dart';

/// Cyber-styled software update telemetry card for Desktop Profile & Settings.
class DesktopUpdateCard extends StatefulWidget {
  const DesktopUpdateCard({super.key, this.updateService});

  final AppUpdateService? updateService;

  @override
  State<DesktopUpdateCard> createState() => _DesktopUpdateCardState();
}

class _DesktopUpdateCardState extends State<DesktopUpdateCard> {
  late final AppUpdateService _service;
  String _versionStr = '1.3.4';
  int _buildNumber = 29;
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
              style: AxisFonts.spaceGrotesk(color: AxisColors.priorityHigh, fontSize: 12),
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
                        : 'Axis Desktop is up to date (v$_versionStr)',
                    style: AxisFonts.spaceGrotesk(
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

  void _showUpdateLog() {
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

    return InkWell(
      onTap: _showUpdateLog,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AxisColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AxisColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isAr ? 'إصدار سطح المكتب والتحديثات' : 'DESKTOP RELEASE & SYSTEM UPDATES',
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AxisColors.textHigh,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.tertiary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AxisColors.tertiary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              isAr ? 'سجل التحديثات ↗' : 'Update Log ↗',
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Axis System Engine v$_versionStr • ${_service.currentPlatform.toUpperCase()}',
                        style: AxisFonts.jetBrainsMono(
                          fontSize: 10.5,
                          color: AxisColors.textDim,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Update Log Button
                Expanded(
                  child: TextButton.icon(
                    key: const ValueKey('desktop_view_update_log_button'),
                    onPressed: _showUpdateLog,
                    icon: const Icon(Icons.history_rounded, size: 14, color: AxisColors.tertiary),
                    label: Text(
                      isAr ? 'سجل التحديثات' : 'Update Log',
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.tertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      backgroundColor: AxisColors.tertiary.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AxisColors.tertiary.withValues(alpha: 0.25)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Check for Updates Button
                Expanded(
                  child: InkWell(
                    key: const ValueKey('desktop_check_for_updates_button'),
                    onTap: _isChecking ? null : _handleCheckForUpdates,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: AxisColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AxisColors.primary.withValues(alpha: 0.4)),
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded, size: 14, color: AxisColors.primarySoft),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    isAr ? 'فحص التحديثات' : 'Check for Updates',
                                    style: AxisFonts.spaceGrotesk(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AxisColors.primarySoft,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
