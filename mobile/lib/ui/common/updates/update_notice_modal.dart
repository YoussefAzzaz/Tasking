import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    this.currentVersion = '1.2.0',
    this.updateService,
  });

  final UpdateInfo updateInfo;
  final String currentVersion;
  final AppUpdateService? updateService;

  static Future<void> show(
    BuildContext context, {
    required UpdateInfo updateInfo,
    String currentVersion = '1.2.0',
    AppUpdateService? updateService,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (_) => UpdateNoticeModal(
        updateInfo: updateInfo,
        currentVersion: currentVersion,
        updateService: updateService,
      ),
    );
  }

  @override
  State<UpdateNoticeModal> createState() => _UpdateNoticeModalState();
}

class _UpdateNoticeModalState extends State<UpdateNoticeModal> {
  late final AppUpdateService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.updateService ?? AppUpdateService();
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
                          ver: 'v${widget.currentVersion}',
                          color: AxisColors.textMuted,
                        ),
                        Icon(
                          isAr ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
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
                            style: GoogleFonts.jetBrainsMono(
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
                      style: GoogleFonts.spaceGrotesk(
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
                          style: GoogleFonts.jetBrainsMono(
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
                  style: GoogleFonts.spaceGrotesk(
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
                  style: GoogleFonts.jetBrainsMono(
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
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              color: AxisColors.textDim,
            ),
          ),
          Text(
            ver,
            style: GoogleFonts.jetBrainsMono(
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
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AxisColors.textHigh,
                ),
              ),
              Text(
                '$percentInt%',
                style: GoogleFonts.jetBrainsMono(
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
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AxisColors.textDim,
                ),
              ),
              Text(
                isAr ? 'لا تغلق التطبيق' : 'Keep app open',
                style: GoogleFonts.spaceGrotesk(
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
                style: GoogleFonts.spaceGrotesk(
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
                    style: GoogleFonts.spaceGrotesk(
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
                    style: GoogleFonts.spaceGrotesk(
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          // Direct browser download action
          if (showBrowser)
            TextButton.icon(
              key: const ValueKey('update_modal_browser_button'),
              onPressed: _openInBrowser,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                foregroundColor: AxisColors.primarySoft,
              ),
              icon: const Icon(Icons.open_in_browser_rounded, size: 16),
              label: Text(
                isAr ? 'المتصفح' : 'BROWSER',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!info.isMandatory && progress.status != UpdateDownloadStatus.downloading)
                TextButton(
                  key: const ValueKey('update_modal_dismiss_button'),
                  onPressed: _dismiss,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: Text(
                    isAr ? 'لاحقاً' : 'LATER',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.textDim,
                    ),
                  ),
                ),
              const SizedBox(width: 8),

              // Primary Button
              if (progress.status == UpdateDownloadStatus.completed)
                ElevatedButton.icon(
                  key: const ValueKey('update_modal_install_button'),
                  onPressed: _installDownloaded,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AxisColors.tertiary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.install_mobile_rounded, size: 16),
                  label: Text(
                    isAr ? 'تثبيت التحديث' : 'INSTALL NOW',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              else if (progress.status == UpdateDownloadStatus.downloading)
                const SizedBox.shrink()
              else
                ElevatedButton.icon(
                  key: const ValueKey('update_modal_download_button'),
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: info.isMandatory ? AxisColors.priorityHigh : AxisColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    isAr ? 'تحديث الآن' : 'UPDATE NOW',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
