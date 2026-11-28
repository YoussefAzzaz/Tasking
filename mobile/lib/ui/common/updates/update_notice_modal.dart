import 'dart:async';

import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/domain/update_checker.dart';

/// Cyber-styled system update modal presenting release notes,
/// live download progress bar, and 1-tap installation.
class UpdateNoticeModal extends StatefulWidget {
  const UpdateNoticeModal({
    super.key,
    required this.updateInfo,
    // Root-cause fix (stale v1.2.0): Previously defaulted to hardcoded `'1.2.0'`,
    // causing callers that omitted `currentVersion` (auto-check / banner) to
    // always show `Current: v1.2.0`. Keeping it nullable lets State resolve the
    // actual installed version from `AppUpdateService`.
    this.currentVersion,
    this.updateService,
  });

  final UpdateInfo updateInfo;
  final String? currentVersion;
  final AppUpdateService? updateService;

  static Future<void>? _activeModalFuture;

  /// Whether an update modal dialog is currently open on screen.
  static bool get isShowing => _activeModalFuture != null;

  @visibleForTesting
  static void resetModalStateForTesting() {
    _activeModalFuture = null;
  }

  static Future<void> show(
    BuildContext context, {
    required UpdateInfo updateInfo,
    String? currentVersion,
    AppUpdateService? updateService,
  }) {
    // Root-cause fix (stacked modals): Previously `show()` pushed a new
    // `showDialog` route unconditionally, so concurrent or repeated triggers
    // stacked multiple UpdateNoticeModal dialogs. Reusing `_activeModalFuture`
    // ensures at most one modal dialog can be open at a time.
    if (_activeModalFuture != null) {
      return _activeModalFuture!;
    }
    final service = updateService ?? AppUpdateService();
    final resolvedVersion = currentVersion ?? service.cachedVersionLabel;
    final future = showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (_) => UpdateNoticeModal(
        updateInfo: updateInfo,
        currentVersion: resolvedVersion,
        updateService: service,
      ),
    );
    _activeModalFuture = future;
    future.whenComplete(() {
      if (identical(_activeModalFuture, future)) {
        _activeModalFuture = null;
      }
    });
    return future;
  }

  @override
  State<UpdateNoticeModal> createState() => _UpdateNoticeModalState();
}

class _UpdateNoticeModalState extends State<UpdateNoticeModal> {
  late final AppUpdateService _service;
  String? _resolvedCurrentVersion;

  @override
  void initState() {
    super.initState();
    _service = widget.updateService ?? AppUpdateService();
    _resolvedCurrentVersion =
        widget.currentVersion ?? _service.cachedVersionLabel;
    if (_resolvedCurrentVersion == null) {
      unawaited(_loadInstalledVersion());
    }
  }

  Future<void> _loadInstalledVersion() async {
    final installed = await _service.getInstalledVersion();
    if (!mounted) return;
    setState(() {
      _resolvedCurrentVersion = installed.displayVersion;
    });
  }

  void _startDownload() {
    _service.downloadUpdate(widget.updateInfo).then((file) {
      if (file != null && mounted) {
        // Automatically attempt install once download completes!
        _service.installUpdate(file.path);
      }
    });
  }

  void _installDownloaded() {
    final path = _service.downloadProgressNotifier.value.savedFilePath;
    if (path != null) {
      _service.installUpdate(path);
    }
  }

  void _dismiss() {
    _service.dismissUpdate(widget.updateInfo.version);
    Navigator.of(context).pop();
  }

  Future<void> _openInBrowser() async {
    final url = widget.updateInfo.downloadUrl.isNotEmpty
        ? widget.updateInfo.downloadUrl
        : 'https://github.com/${_service.githubRepo}/releases/latest';
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UpdateNoticeModal] Error launching browser download: $e');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isArabic;
    final info = widget.updateInfo;

    return PopScope(
      canPop: !info.isMandatory,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: AxisColors.canvasBase,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: info.isMandatory
                  ? AxisColors.priorityHigh.withValues(alpha: 0.6)
                  : AxisColors.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (info.isMandatory ? AxisColors.priorityHigh : AxisColors.primary)
                    .withValues(alpha: 0.25),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              _buildHeader(isAr, info),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Version badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildVersionBadge(
                          label: isAr ? 'الحالي' : 'Current',
                          ver: _resolvedCurrentVersion != null
                              ? 'v$_resolvedCurrentVersion'
                              : '...',
                          color: AxisColors.textMuted,
                        ),
                        // Root cause: arrow_forward_rounded auto-mirrors in RTL; ternary flipped twice.
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AxisColors.textDim,
                        ),
                        _buildVersionBadge(
                          label: isAr ? 'الجديد' : 'New',
                          ver: 'v${info.version}',
                          color: AxisColors.primarySoft,
                          isHighlight: true,
                        ),
                        if (info.fileSizeBytes != null && info.fileSizeBytes! > 0)
                          Text(
                            _formatBytes(info.fileSizeBytes!),
                            style: AxisFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AxisColors.textDim,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Changelog title
                    Text(
                      isAr ? 'ما الجديد في هذا الإصدار:' : "What's New in this Release:",
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Changelog Scrollable Card
                    Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          info.releaseNotes.isNotEmpty
                              ? info.releaseNotes
                              : (isAr
                                  ? 'تحسينات عامة في الأداء وإصلاح الأخطاء.'
                                  : 'Performance enhancements and stability fixes.'),
                          style: AxisFonts.jetBrainsMono(
                            fontSize: 11.5,
                            height: 1.5,
                            color: AxisColors.textHigh.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Live Download Progress Area
                    ValueListenableBuilder<UpdateDownloadProgress>(
                      valueListenable: _service.downloadProgressNotifier,
                      builder: (context, progress, _) {
                        return _buildProgressArea(isAr, progress);
                      },
                    ),
                  ],
                ),
              ),

              // Action Buttons
              ValueListenableBuilder<UpdateDownloadProgress>(
                valueListenable: _service.downloadProgressNotifier,
                builder: (context, progress, _) {
                  return _buildActions(isAr, info, progress);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAr, UpdateInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
        border: Border(
          bottom: BorderSide(color: AxisColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (info.isMandatory ? AxisColors.priorityHigh : AxisColors.primary)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.system_update_rounded,
              color: info.isMandatory ? AxisColors.priorityHigh : AxisColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.isMandatory
                      ? (isAr ? 'تحديث إلزامي للنظام' : 'CRITICAL UPDATE REQUIRED')
                      : (isAr ? 'تحديث جديد للنظام' : 'SYSTEM UPDATE AVAILABLE'),
                  style: AxisFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: info.isMandatory ? AxisColors.priorityHigh : AxisColors.primarySoft,
                  ),
                ),
                Text(
                  info.releaseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AxisFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AxisColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!info.isMandatory)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
              visualDensity: VisualDensity.compact,
              onPressed: _dismiss,
            ),
        ],
      ),
    );
  }

  Widget _buildVersionBadge({
    required String label,
    required String ver,
    required Color color,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight
            ? AxisColors.primary.withValues(alpha: 0.15)
            : AxisColors.surfaceHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlight ? AxisColors.primary.withValues(alpha: 0.4) : AxisColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AxisFonts.spaceGrotesk(
              fontSize: 10,
              color: AxisColors.textDim,
            ),
          ),
          Text(
            ver,
            style: AxisFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressArea(bool isAr, UpdateDownloadProgress progress) {
    if (progress.status == UpdateDownloadStatus.idle) {
      return const SizedBox.shrink();
    }

    if (progress.status == UpdateDownloadStatus.downloading) {
      final percentInt = (progress.percentage * 100).toInt();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAr ? 'جارٍ تحميل التحديث...' : 'Downloading update package...',
                style: AxisFonts.spaceGrotesk(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AxisColors.textHigh,
                ),
              ),
              Text(
                '$percentInt%',
                style: AxisFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AxisColors.secondarySoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.percentage > 0 ? progress.percentage : null,
              minHeight: 6,
              backgroundColor: AxisColors.surfaceHigh.withValues(alpha: 0.4),
              valueColor: const AlwaysStoppedAnimation<Color>(AxisColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress.totalBytes > 0
                    ? '${_formatBytes(progress.receivedBytes)} / ${_formatBytes(progress.totalBytes)}'
                    : _formatBytes(progress.receivedBytes),
                style: AxisFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AxisColors.textDim,
                ),
              ),
              Text(
                isAr ? 'لا تغلق التطبيق' : 'Keep app open',
                style: AxisFonts.spaceGrotesk(
                  fontSize: 10,
                  color: AxisColors.textDim,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (progress.status == UpdateDownloadStatus.completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AxisColors.tertiary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AxisColors.tertiary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AxisColors.tertiary, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isAr
                    ? 'اكتمل التحميل! اضغط أدناه للتثبيت فوراً.'
                    : 'Download complete! Tap Install to update.',
                style: AxisFonts.spaceGrotesk(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AxisColors.tertiary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (progress.status == UpdateDownloadStatus.failed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AxisColors.priorityHigh.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AxisColors.priorityHigh.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AxisColors.priorityHigh, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progress.error ?? (isAr ? 'فشل التحميل' : 'Download failed. Tap retry or open in browser.'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 11,
                      color: AxisColors.priorityHigh,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _openInBrowser,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.open_in_browser_rounded, size: 13, color: AxisColors.primarySoft),
                  const SizedBox(width: 4),
                  Text(
                    isAr ? 'التحميل من المتصفح مباشرة' : 'Download via browser directly',
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.primarySoft,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActions(
    bool isAr,
    UpdateInfo info,
    UpdateDownloadProgress progress,
  ) {
    final showBrowser = progress.status != UpdateDownloadStatus.completed;
    final showDismiss = !info.isMandatory && progress.status != UpdateDownloadStatus.downloading;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (progress.status == UpdateDownloadStatus.completed)
            ElevatedButton.icon(
              key: const ValueKey('update_modal_install_button'),
              onPressed: _installDownloaded,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AxisColors.tertiary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.install_mobile_rounded, size: 17),
              label: Text(
                isAr ? 'تثبيت التحديث' : 'INSTALL NOW',
                style: AxisFonts.spaceGrotesk(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: isAr ? 0.0 : 0.8,
                ),
              ),
            )
          else if (progress.status != UpdateDownloadStatus.downloading)
            ElevatedButton.icon(
              key: const ValueKey('update_modal_download_button'),
              onPressed: _startDownload,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: info.isMandatory ? AxisColors.priorityHigh : AxisColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(
                progress.status == UpdateDownloadStatus.failed
                    ? Icons.refresh_rounded
                    : Icons.download_rounded,
                size: 17,
              ),
              label: Text(
                progress.status == UpdateDownloadStatus.failed
                    ? (isAr ? 'إعادة المحاولة' : 'RETRY UPDATE')
                    : (isAr ? 'تحديث الآن' : 'UPDATE NOW'),
                style: AxisFonts.spaceGrotesk(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: isAr ? 0.0 : 0.8,
                ),
              ),
            ),
          if (showBrowser || showDismiss) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (showBrowser)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('update_modal_browser_button'),
                      onPressed: _openInBrowser,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AxisColors.primarySoft,
                        side: const BorderSide(color: AxisColors.borderSubtle),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                      label: Text(
                        isAr ? 'المتصفح' : 'BROWSER',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (showBrowser && showDismiss) const SizedBox(width: 10),
                if (showDismiss)
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('update_modal_dismiss_button'),
                      onPressed: _dismiss,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        backgroundColor: AxisColors.surfaceHigh.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isAr ? 'لاحقاً' : 'LATER',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
