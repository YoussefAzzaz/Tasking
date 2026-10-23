import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';

/// Formatting toolbar providing one-tap insertion of markdown & markup:
/// Ordered lists, bullet points, checklists, headings, bold, italic, quotes, code, and timestamp logs.
class NoteFormatToolbar extends StatelessWidget {
  const NoteFormatToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onChanged;

  void _applyFormat(String prefix, [String suffix = '']) {
    final text = controller.text;
    final selection = controller.selection;

    int start = selection.start;
    int end = selection.end;

    // If no active selection, append at current cursor position or end of text
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final selectedText = text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';
    final newText = text.replaceRange(start, end, replacement);

    // If we wrapped selected text, place cursor after suffix; if empty, place cursor inside
    final newCursorPos = selectedText.isNotEmpty
        ? start + replacement.length
        : start + prefix.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    focusNode.requestFocus();
    onChanged?.call();
  }

  void _insertLinePrefix(String linePrefix) {
    final text = controller.text;
    final selection = controller.selection;
    int start = selection.start;
    if (start < 0 || start > text.length) start = text.length;

    // Find the start of the current line safely
    int lineStart = 0;
    if (start > 0) {
      final lastNewline = text.lastIndexOf('\n', start - 1);
      if (lastNewline >= 0) {
        lineStart = lastNewline + 1;
      }
    }

    int lineEnd = text.length;
    final nextNewline = text.indexOf('\n', lineStart);
    if (nextNewline >= 0) lineEnd = nextNewline;

    final currentLine = text.substring(lineStart, lineEnd);
    final prefixMatch = RegExp(r'^(\s*)([-*+]\s+\[[ xX]?\]\s+|[-*+•]\s+|\d+[\.\)]\s+|#{1,6}\s+|>\s+)').firstMatch(currentLine);
    int replaceEnd = lineStart;
    if (prefixMatch != null) {
      final indent = prefixMatch.group(1) ?? '';
      final existingPrefix = prefixMatch.group(2) ?? '';
      replaceEnd = lineStart + indent.length + existingPrefix.length;
    }

    final newText = text.replaceRange(lineStart, replaceEnd, linePrefix);
    final offsetDiff = linePrefix.length - (replaceEnd - lineStart);
    final newCursorPos = (start + offsetDiff).clamp(0, newText.length);

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    focusNode.requestFocus();
    onChanged?.call();
  }

  void _insertTimeLog() {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());
    _insertLinePrefix('**$timeStr** - ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        children: [
          // Bold
          _ToolbarItem(
            tooltip: 'Bold (**text**)',
            label: 'B',
            isBold: true,
            onTap: () => _applyFormat('**', '**'),
          ),

          // Italic
          _ToolbarItem(
            tooltip: 'Italic (*text*)',
            label: 'I',
            isItalic: true,
            onTap: () => _applyFormat('*', '*'),
          ),

          const _ToolbarDivider(),

          // Heading 2
          _ToolbarItem(
            tooltip: 'Heading 2 (## Title)',
            label: 'H2',
            isBold: true,
            onTap: () => _insertLinePrefix('## '),
          ),

          // Heading 3
          _ToolbarItem(
            tooltip: 'Heading 3 (### Subtitle)',
            label: 'H3',
            onTap: () => _insertLinePrefix('### '),
          ),

          const _ToolbarDivider(),

          // Ordered list (1., 2.)
          _ToolbarItem(
            tooltip: 'Numbered List (1. Item)',
            icon: Icons.format_list_numbered_rounded,
            onTap: () => _insertLinePrefix('1. '),
          ),

          // Bullet points / unordered list (•)
          _ToolbarItem(
            tooltip: 'Bullet Points (- Item)',
            icon: Icons.format_list_bulleted_rounded,
            onTap: () => _insertLinePrefix('- '),
          ),

          // Checklist
          _ToolbarItem(
            tooltip: 'Checklist (- [ ] Item)',
            icon: Icons.check_box_outlined,
            onTap: () => _insertLinePrefix('- [ ] '),
          ),

          const _ToolbarDivider(),

          // Quote
          _ToolbarItem(
            tooltip: 'Quote (> Note)',
            icon: Icons.format_quote_rounded,
            onTap: () => _insertLinePrefix('> '),
          ),

          // Code
          _ToolbarItem(
            tooltip: 'Inline Code (`code`)',
            icon: Icons.code_rounded,
            onTap: () => _applyFormat('`', '`'),
          ),

          // Timestamp Event Log (Great for Daily Journal)
          _ToolbarItem(
            tooltip: 'Log Event Time (**HH:mm** - )',
            icon: Icons.schedule_rounded,
            accentColor: AxisColors.secondary,
            onTap: _insertTimeLog,
          ),
        ],
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: AxisColors.borderSubtle,
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  const _ToolbarItem({
    required this.tooltip,
    required this.onTap,
    this.icon,
    this.label,
    this.isBold = false,
    this.isItalic = false,
    this.accentColor,
  });

  final String tooltip;
  final VoidCallback onTap;
  final IconData? icon;
  final String? label;
  final bool isBold;
  final bool isItalic;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AxisColors.textHigh;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, size: 16, color: color)
              : Text(
                  label ?? '',
                  style: TextStyle(
                    color: color,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}
