import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';

/// Floating themed snackbar with a timed UNDO action for destructive
/// operations. [onUndo] runs the restore when the user taps UNDO before the
/// window closes.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required Future<void> Function() onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: duration,
        elevation: 0,
        backgroundColor: AxisColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AxisColors.borderGlass2, width: 1),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Text(
          message,
          style: GoogleFonts.getFont(
            'Geist',
            fontSize: 12.5,
            color: AxisColors.textHigh,
          ),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AxisColors.tertiary,
          onPressed: () => onUndo(),
        ),
      ),
    );
}
