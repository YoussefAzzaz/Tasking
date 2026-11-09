import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Clean, high-contrast floating toast / snackbar notification for AXIS
/// designed according to the Obsidian Kinetic design system.
///
/// Guarantees crystal-clear font readability (WCAG AAA contrast) in both
/// dark obsidian mode and light mode across mobile and desktop.
class AxisSnackBar {
  AxisSnackBar._();

  /// Displays a floating notification with high-contrast text and clean glass styling.
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? iconColor,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    bool isError = false,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final effectiveBg = backgroundColor ??
        (isError ? const Color(0xFF2C1318) : AxisColors.surfaceHigh);

    final effectiveIconColor = iconColor ??
        (isError
            ? AxisColors.error
            : (icon == Icons.delete_outline_rounded
                ? AxisColors.priorityHigh
                : AxisColors.secondarySoft));

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: effectiveBg,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError
                ? AxisColors.error.withValues(alpha: 0.4)
                : AxisColors.borderGlass2,
            width: 1.2,
          ),
        ),
        action: action,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: effectiveIconColor),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.getFont(
                  'Geist',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: AxisColors.textHigh, // High-contrast crisp white (#F8FAFC)
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Convenience helper for deletion confirmations
  static void showDeleted(
    BuildContext context, {
    required String itemTitle,
    String? itemType,
    VoidCallback? onUndo,
  }) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final message = isArabic
        ? 'تم حذف "$itemTitle"'
        : '${itemType != null ? '$itemType ' : ''}"$itemTitle" deleted';
    show(
      context,
      message: message,
      icon: Icons.delete_outline_rounded,
      iconColor: AxisColors.priorityHigh,
      action: onUndo != null
          ? SnackBarAction(
              label: isArabic ? 'تراجع' : 'UNDO',
              textColor: AxisColors.primarySoft,
              onPressed: onUndo,
            )
          : null,
    );
  }
}

