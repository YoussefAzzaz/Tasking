import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/domain/update_checker.dart';
import 'package:axis/ui/common/updates/update_notice_modal.dart';

/// Cyber-styled sticky banner displayed when a new version of Axis is available.
class UpdateNoticeBanner extends StatelessWidget {
  const UpdateNoticeBanner({super.key, this.updateService});

  final AppUpdateService? updateService;

  @override
  Widget build(BuildContext context) {
    final service = updateService ?? AppUpdateService();

    return ValueListenableBuilder<UpdateInfo?>(
      valueListenable: service.availableUpdateNotifier,
      builder: (context, update, _) {
        if (update == null) return const SizedBox.shrink();

        final isAr = context.isArabic;

        return Material(
          color: Colors.transparent,
          child: Container(
            key: const ValueKey('update_notice_banner'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AxisColors.primary.withValues(alpha: 0.12),
              border: Border(
                bottom: BorderSide(
                  color: AxisColors.primary.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: AxisColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AxisColors.primarySoft,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr
                        ? 'إصدار جديد متاح (v${update.version}) • انقر للتحميل والتثبيت'
                        : 'New release ready (v${update.version}) • Tap to download & install',
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textHigh,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  key: const ValueKey('update_banner_install_button'),
                  onTap: () {
                    UpdateNoticeModal.show(
                      context,
                      updateInfo: update,
                      currentVersion: service.cachedVersionLabel,
                      updateService: service,
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AxisColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAr ? 'تحديث' : 'UPDATE',
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (!update.isMandatory)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 14, color: AxisColors.textDim),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    onPressed: () => service.dismissUpdate(update.version),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
