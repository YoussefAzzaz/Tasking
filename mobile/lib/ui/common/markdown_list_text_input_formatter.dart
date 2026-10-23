import 'package:flutter/services.dart';

/// TextInputFormatter that handles smart markdown list continuation and termination:
///
/// 1. Continuation on Enter / Newline:
///   - Checklist (`- [ ] item`, `- [x] item`) -> continues with `- [ ] ` (unchecked)
///   - Ordered list (`1. item`, `1) item`) -> continues with next number (e.g. `2. `)
///   - Unordered list (`- item`, `* item`, `+ item`, `• item`) -> continues with same bullet
///   - Preserves indentation (spaces/tabs) on the new line
///
/// 2. List Termination / Erasure:
///   - Pressing Enter on an empty list item removes the marker from the line and stops the list
///   - Erasing/backspacing on an empty list item removes the marker in one backspace and stops the list
///   - When the list marker is removed, the user can continue typing normal text
///
/// 3. Shift+Enter (hardware keyboard):
///   - Soft break inserting newline without continuing list prefix
class MarkdownListTextInputFormatter extends TextInputFormatter {
  const MarkdownListTextInputFormatter();

  // Pattern for checklist: optional indent, marker (- [ ] or - [x] or * [ ] or + [ ]), content
  static final _checklistRegex = RegExp(r'^(\s*)([-*+]\s+\[[ xX]?\]\s+)(.*)$');

  // Pattern for ordered list: optional indent, number, delimiter (. or )), whitespace, content
  static final _orderedRegex = RegExp(r'^(\s*)(\d+)([\.\)])\s+(.*)$');

  // Pattern for unordered list: optional indent, bullet (-, *, +, •), whitespace, content
  static final _unorderedRegex = RegExp(r'^(\s*)([-*+•])\s+(.*)$');

  // Empty list item patterns (line contains ONLY the list marker and optional whitespace)
  static final _emptyChecklistRegex = RegExp(r'^(\s*)[-*+]\s+\[[ xX]?\]\s*$');
  static final _emptyOrderedRegex = RegExp(r'^(\s*)\d+[\.\)]\s*$');
  static final _emptyUnorderedRegex = RegExp(r'^(\s*)[-*+•]\s*$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Calculate diff between oldValue and newValue
    // When editing at a collapsed cursor, identify exact insertion/deletion to prevent
    // diff scanning overshooting matching trailing newlines (e.g. in Journal templates).
    int diffStart = 0;
    int oldDiffEnd = 0;
    int newDiffEnd = 0;
    String inserted = '';
    bool diffIdentified = false;

    final isCollapsed = oldValue.selection.isValid &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.baseOffset >= 0 &&
        oldValue.selection.baseOffset <= oldValue.text.length;

    if (isCollapsed) {
      final cursor = oldValue.selection.baseOffset;

      if (_isSingleCharInsertion(oldValue.text, newValue.text, cursor, '\n')) {
        diffStart = cursor;
        oldDiffEnd = cursor;
        newDiffEnd = cursor + 1;
        inserted = '\n';
        diffIdentified = true;
      } else if (_isTwoCharInsertion(
          oldValue.text, newValue.text, cursor, '\r\n')) {
        diffStart = cursor;
        oldDiffEnd = cursor;
        newDiffEnd = cursor + 2;
        inserted = '\r\n';
        diffIdentified = true;
      } else if (_isSingleCharDeletionBefore(
          oldValue.text, newValue.text, cursor)) {
        diffStart = cursor - 1;
        oldDiffEnd = cursor;
        newDiffEnd = cursor - 1;
        inserted = '';
        diffIdentified = true;
      } else if (_isSingleCharDeletionAt(
          oldValue.text, newValue.text, cursor)) {
        diffStart = cursor;
        oldDiffEnd = cursor + 1;
        newDiffEnd = cursor;
        inserted = '';
        diffIdentified = true;
      }
    }

    // Fall back to general diff scanning if not matched by cursor-aware checks
    if (!diffIdentified) {
      diffStart = 0;
      while (diffStart < oldValue.text.length &&
          diffStart < newValue.text.length &&
          oldValue.text[diffStart] == newValue.text[diffStart]) {
        diffStart++;
      }

      oldDiffEnd = oldValue.text.length;
      newDiffEnd = newValue.text.length;
      while (oldDiffEnd > diffStart &&
          newDiffEnd > diffStart &&
          oldValue.text[oldDiffEnd - 1] == newValue.text[newDiffEnd - 1]) {
        oldDiffEnd--;
        newDiffEnd--;
      }

      inserted = newValue.text.substring(diffStart, newDiffEnd);
    }

    // 2. Check for Backspace / single-character deletion on an empty list item
    if (inserted.isEmpty && oldDiffEnd - diffStart == 1) {
      final handled = _handleDeletion(oldValue, diffStart);
      if (handled != null) {
        return handled;
      }
    }

    // 3. Check for Newline insertion (Enter key)
    // Only continue lists if user pressed Enter at a collapsed cursor (not replacing a selection range)
    if ((inserted == '\n' || inserted == '\r\n') && oldDiffEnd == diffStart) {
      // If hardware Shift key is held (desktop), perform a soft break without prefix
      try {
        if (HardwareKeyboard.instance.isShiftPressed) {
          return newValue;
        }
      } catch (_) {
        // Fallback for headless test environments
      }

      final handled = _handleNewline(oldValue, diffStart, inserted);
      if (handled != null) {
        return handled;
      }
    }

    return newValue;
  }

  /// Handles Backspace or Delete on a line that contains an empty list element.
  /// When user erases the element, the entire prefix is cleared so the list stops.
  TextEditingValue? _handleDeletion(TextEditingValue oldValue, int diffStart) {
    int lineStart = 0;
    if (diffStart > 0) {
      final lastNewline = oldValue.text.lastIndexOf('\n', diffStart - 1);
      if (lastNewline >= 0) {
        lineStart = lastNewline + 1;
      }
    }

    int lineEnd = oldValue.text.length;
    final nextNewline = oldValue.text.indexOf('\n', diffStart);
    if (nextNewline >= 0) {
      lineEnd = nextNewline;
      if (lineEnd > lineStart && oldValue.text[lineEnd - 1] == '\r') {
        lineEnd--;
      }
    }

    final lineText = oldValue.text.substring(lineStart, lineEnd);

    final isEmptyList = _emptyChecklistRegex.hasMatch(lineText) ||
        _emptyOrderedRegex.hasMatch(lineText) ||
        _emptyUnorderedRegex.hasMatch(lineText);

    if (isEmptyList && diffStart >= lineStart && diffStart <= lineEnd) {
      // Erase the empty list element completely from this line
      final newText = oldValue.text.replaceRange(lineStart, lineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    return null;
  }

  /// Handles Enter / Newline on a line.
  /// - If the current line is an empty list item, clears the prefix and stops the list.
  /// - If the line is an active list item, creates the next item (next number or new element).
  TextEditingValue? _handleNewline(
    TextEditingValue oldValue,
    int diffStart,
    String newlineStr,
  ) {
    int lineStart = 0;
    if (diffStart > 0) {
      final lastNewline = oldValue.text.lastIndexOf('\n', diffStart - 1);
      if (lastNewline >= 0) {
        lineStart = lastNewline + 1;
      }
    }

    int lineEnd = oldValue.text.length;
    final nextNewline = oldValue.text.indexOf('\n', diffStart);
    if (nextNewline >= 0) {
      lineEnd = nextNewline;
      if (lineEnd > lineStart && oldValue.text[lineEnd - 1] == '\r') {
        lineEnd--;
      }
    }

    String lineBeforeCursor = oldValue.text.substring(lineStart, diffStart);
    if (lineBeforeCursor.endsWith('\r')) {
      lineBeforeCursor =
          lineBeforeCursor.substring(0, lineBeforeCursor.length - 1);
    }
    final lineAfterCursor = oldValue.text.substring(diffStart, lineEnd);

    // Case A: User pressed Enter on an empty list item -> STOP THE LIST!
    final isEmptyList = _emptyChecklistRegex.hasMatch(lineBeforeCursor) ||
        _emptyOrderedRegex.hasMatch(lineBeforeCursor) ||
        _emptyUnorderedRegex.hasMatch(lineBeforeCursor);

    if (isEmptyList && lineAfterCursor.trim().isEmpty) {
      // Clear the empty prefix, leaving a blank line with cursor ready for normal text
      final newText = oldValue.text.replaceRange(lineStart, lineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // Case B: Checklist continuation (- [ ] or - [x] or * [ ])
    // Checklist is checked before unordered list to prevent `- [ ]` matching `-`
    final checklistMatch = _checklistRegex.firstMatch(lineBeforeCursor);
    if (checklistMatch != null) {
      final indent = checklistMatch.group(1) ?? '';
      // New checklist item is always unchecked
      final nextPrefix = '$indent- [ ] ';
      return _insertContinuation(
        oldValue: oldValue,
        diffStart: diffStart,
        lineEnd: lineEnd,
        lineAfterCursor: lineAfterCursor,
        nextPrefix: nextPrefix,
        newlineStr: newlineStr,
      );
    }

    // Case C: Ordered list continuation (1. , 2) )
    final orderedMatch = _orderedRegex.firstMatch(lineBeforeCursor);
    if (orderedMatch != null) {
      final indent = orderedMatch.group(1) ?? '';
      final currentNum = int.tryParse(orderedMatch.group(2) ?? '1') ?? 1;
      final delim = orderedMatch.group(3) ?? '.';
      final nextPrefix = '$indent${currentNum + 1}$delim ';
      return _insertContinuation(
        oldValue: oldValue,
        diffStart: diffStart,
        lineEnd: lineEnd,
        lineAfterCursor: lineAfterCursor,
        nextPrefix: nextPrefix,
        newlineStr: newlineStr,
      );
    }

    // Case D: Unordered list continuation (-, *, +, •)
    final unorderedMatch = _unorderedRegex.firstMatch(lineBeforeCursor);
    if (unorderedMatch != null) {
      final indent = unorderedMatch.group(1) ?? '';
      final bullet = unorderedMatch.group(2) ?? '-';
      final nextPrefix = '$indent$bullet ';
      return _insertContinuation(
        oldValue: oldValue,
        diffStart: diffStart,
        lineEnd: lineEnd,
        lineAfterCursor: lineAfterCursor,
        nextPrefix: nextPrefix,
        newlineStr: newlineStr,
      );
    }

    return null;
  }

  /// Inserts the newline and continuation prefix, carrying over any remaining text on the line.
  TextEditingValue _insertContinuation({
    required TextEditingValue oldValue,
    required int diffStart,
    required int lineEnd,
    required String lineAfterCursor,
    required String nextPrefix,
    required String newlineStr,
  }) {
    // If text after cursor starts with a single space, trim it to avoid double spaces
    String remainder = lineAfterCursor;
    if (remainder.startsWith(' ')) {
      remainder = remainder.substring(1);
    }

    final replacement = '$newlineStr$nextPrefix$remainder';
    final newText = oldValue.text.replaceRange(diffStart, lineEnd, replacement);
    final newCursorPos = diffStart + newlineStr.length + nextPrefix.length;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  static bool _isSingleCharInsertion(
    String oldText,
    String newText,
    int cursor,
    String char,
  ) {
    if (newText.length != oldText.length + 1) return false;
    if (cursor < 0 || cursor > oldText.length) return false;
    if (newText[cursor] != char) return false;

    for (int i = 0; i < cursor; i++) {
      if (oldText[i] != newText[i]) return false;
    }
    for (int i = cursor; i < oldText.length; i++) {
      if (oldText[i] != newText[i + 1]) return false;
    }
    return true;
  }

  static bool _isTwoCharInsertion(
    String oldText,
    String newText,
    int cursor,
    String chars,
  ) {
    if (newText.length != oldText.length + 2) return false;
    if (cursor < 0 || cursor > oldText.length) return false;
    if (newText.substring(cursor, cursor + 2) != chars) return false;

    for (int i = 0; i < cursor; i++) {
      if (oldText[i] != newText[i]) return false;
    }
    for (int i = cursor; i < oldText.length; i++) {
      if (oldText[i] != newText[i + 2]) return false;
    }
    return true;
  }

  static bool _isSingleCharDeletionBefore(
    String oldText,
    String newText,
    int cursor,
  ) {
    if (cursor <= 0 || cursor > oldText.length) return false;
    if (newText.length != oldText.length - 1) return false;

    final deleteIndex = cursor - 1;
    for (int i = 0; i < deleteIndex; i++) {
      if (oldText[i] != newText[i]) return false;
    }
    for (int i = deleteIndex; i < newText.length; i++) {
      if (oldText[i + 1] != newText[i]) return false;
    }
    return true;
  }

  static bool _isSingleCharDeletionAt(
    String oldText,
    String newText,
    int cursor,
  ) {
    if (cursor < 0 || cursor >= oldText.length) return false;
    if (newText.length != oldText.length - 1) return false;

    final deleteIndex = cursor;
    for (int i = 0; i < deleteIndex; i++) {
      if (oldText[i] != newText[i]) return false;
    }
    for (int i = deleteIndex; i < newText.length; i++) {
      if (oldText[i + 1] != newText[i]) return false;
    }
    return true;
  }
}
