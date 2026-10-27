import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import 'accent_button.dart';
import 'ghost_button.dart';

/// Modal destructive-action confirmation styled to the Obsidian Kinetic dialog
/// language. Resolves `true` only when the user explicitly confirms.
///
/// Fully keyboard-operable: focus starts on Cancel (the safe default), Tab
/// moves to the confirm action, Enter/Space activate the focused button, and
/// Esc always cancels.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Delete',
    this.destructive = true,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    bool destructive = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AxisColors.danger : AxisColors.primary;

    return Focus(
      onKeyEvent: (node, event) {
        // Esc always cancels. Enter/Space activate the focused button —
        // focus starts on Cancel (the safe default).
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop(false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: FocusTraversalGroup(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: AxisColors.canvasBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderGlass2, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        destructive
                            ? Icons.delete_outline_rounded
                            : Icons.help_outline_rounded,
                        size: 20,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          title,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AxisColors.textHigh,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: GoogleFonts.getFont(
                    'Geist',
                    fontSize: 12.5,
                    height: 1.5,
                    color: AxisColors.textMuted,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GhostButton(
                      label: 'Cancel',
                      height: 36,
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 8),
                    AccentButton(
                      label: confirmLabel,
                      height: 36,
                      gradient: destructive
                          ? const LinearGradient(
                              colors: [
                                AxisColors.danger,
                                AxisColors.dangerDeep,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
