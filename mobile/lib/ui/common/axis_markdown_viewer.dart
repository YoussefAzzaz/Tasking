import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';

/// Cyber-minimalist markdown and markup renderer tailored for notes and journal logs.
/// Supports headings (#, ##, ###), ordered lists (1., 2.), bullet points (-, *, •),
/// interactive checklists (- [ ] / - [x]), blockquotes (>), inline bold (**), italic (*), code (`), and dividers (---).
class AxisMarkdownViewer extends StatefulWidget {
  const AxisMarkdownViewer({
    super.key,
    required this.markdown,
    this.baseStyle,
    this.selectable = true,
    this.onMarkdownChanged,
    this.fontScale = 1.0,
  });

  final String markdown;
  final TextStyle? baseStyle;
  final bool selectable;
  final ValueChanged<String>? onMarkdownChanged;
  final double fontScale;

  @override
  State<AxisMarkdownViewer> createState() => _AxisMarkdownViewerState();
}

class _AxisMarkdownViewerState extends State<AxisMarkdownViewer> {
  late String _currentMarkdown;

  @override
  void initState() {
    super.initState();
    _currentMarkdown = widget.markdown;
  }

  @override
  void didUpdateWidget(covariant AxisMarkdownViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.markdown != oldWidget.markdown) {
      _currentMarkdown = widget.markdown;
    }
  }

  void _toggleChecklist(int lineIndex) {
    HapticFeedback.selectionClick();
    final lines = List<String>.from(_currentMarkdown.split('\n'));
    if (lineIndex < 0 || lineIndex >= lines.length) return;

    final line = lines[lineIndex];
    final checklistMatch =
        RegExp(r'^(\s*[-*•]\s+\[)([ xX])(\]\s*.*)$').firstMatch(line);
    if (checklistMatch != null) {
      final prefix = checklistMatch.group(1)!;
      final mark = checklistMatch.group(2)!;
      final suffix = checklistMatch.group(3)!;
      final isCurrentlyChecked = mark.toLowerCase() == 'x';
      final newMark = isCurrentlyChecked ? ' ' : 'x';
      lines[lineIndex] = '$prefix$newMark$suffix';
      final updated = lines.join('\n');
      setState(() {
        _currentMarkdown = updated;
      });
      widget.onMarkdownChanged?.call(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMarkdown.trim().isEmpty) {
      final base = widget.baseStyle ?? Theme.of(context).textTheme.bodyMedium;
      return Text(
        'No notes provided.',
        style: (base ?? const TextStyle()).copyWith(
          fontSize: (base?.fontSize ?? 13.5) * widget.fontScale,
          color: AxisColors.textDim,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final lines = _currentMarkdown.split('\n');
    final blockWidgets = <Widget>[];

    bool inCodeBlock = false;
    final codeBlockLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      // Code Block boundary ```
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          // Close code block
          final codeContent = codeBlockLines.join('\n');
          blockWidgets.add(_buildCodeBlock(context, codeContent));
          codeBlockLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(line);
        continue;
      }

      // Horizontal Divider --- or ***
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        blockWidgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AxisColors.borderSubtle, height: 1),
          ),
        );
        continue;
      }

      // Empty line / paragraph break
      if (trimmed.isEmpty) {
        blockWidgets.add(const SizedBox(height: 8));
        continue;
      }

      // Heading 1 (# ...)
      if (trimmed.startsWith('# ')) {
        final content = trimmed.substring(2).trim();
        blockWidgets.add(_buildHeading(context, content, level: 1));
        continue;
      }

      // Heading 2 (## ...)
      if (trimmed.startsWith('## ')) {
        final content = trimmed.substring(3).trim();
        blockWidgets.add(_buildHeading(context, content, level: 2));
        continue;
      }

      // Heading 3 (### ...)
      if (trimmed.startsWith('### ')) {
        final content = trimmed.substring(4).trim();
        blockWidgets.add(_buildHeading(context, content, level: 3));
        continue;
      }

      // Blockquote (> ...)
      if (trimmed.startsWith('> ') || trimmed == '>') {
        final content = trimmed.length > 2 ? trimmed.substring(2).trim() : '';
        blockWidgets.add(_buildBlockquote(context, content));
        continue;
      }

      // Checklist item (- [ ] ... or - [x] ...)
      final checklistMatch =
          RegExp(r'^(\s*[-*•]\s+\[)([ xX])\]\s*(.*)$').firstMatch(line);
      if (checklistMatch != null) {
        final isChecked = checklistMatch.group(2)?.toLowerCase() == 'x';
        final content = checklistMatch.group(3) ?? '';
        final lineIndex = i;
        blockWidgets.add(
          _buildChecklistItem(
            context,
            content,
            isChecked: isChecked,
            onToggle: () => _toggleChecklist(lineIndex),
          ),
        );
        continue;
      }

      // Ordered list item (e.g. 1. or 12. ...)
      final orderedMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (orderedMatch != null) {
        final number = orderedMatch.group(1) ?? '1';
        final content = orderedMatch.group(2) ?? '';
        blockWidgets.add(_buildOrderedListItem(context, number, content));
        continue;
      }

      // Unordered list / bullet point (-, *, • ...)
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ') || trimmed.startsWith('• ')) {
        final content = trimmed.substring(2).trim();
        blockWidgets.add(_buildBulletListItem(context, content));
        continue;
      }

      // Standard paragraph line
      blockWidgets.add(_buildParagraph(context, line));
    }

    if (inCodeBlock && codeBlockLines.isNotEmpty) {
      blockWidgets.add(_buildCodeBlock(context, codeBlockLines.join('\n')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: blockWidgets,
    );
  }

  Widget _buildHeading(BuildContext context, String text, {required int level}) {
    double fontSize;
    Color color;
    FontWeight weight;
    double topPadding;

    switch (level) {
      case 1:
        fontSize = 19 * widget.fontScale;
        color = AxisColors.textHigh;
        weight = FontWeight.bold;
        topPadding = 12;
        break;
      case 2:
        fontSize = 16 * widget.fontScale;
        color = AxisColors.secondary;
        weight = FontWeight.bold;
        topPadding = 10;
        break;
      case 3:
      default:
        fontSize = 14 * widget.fontScale;
        color = AxisColors.textHigh;
        weight = FontWeight.w600;
        topPadding = 8;
        break;
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 4),
      child: Text.rich(
        _parseInlineSpans(
          text,
          base: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildBlockquote(BuildContext context, String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: const Border(
          left: BorderSide(color: AxisColors.secondary, width: 3),
        ),
      ),
      child: Text.rich(
        _parseInlineSpans(
          text,
          base: TextStyle(
            color: AxisColors.textHigh.withValues(alpha: 0.9),
            fontStyle: FontStyle.italic,
            fontSize: 13 * widget.fontScale,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(
    BuildContext context,
    String text, {
    required bool isChecked,
    VoidCallback? onToggle,
  }) {
    final boxSize = (18 * widget.fontScale).clamp(16.0, 26.0);
    final iconSize = (13 * widget.fontScale).clamp(11.0, 19.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 9),
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  color: isChecked
                      ? AxisColors.success.withValues(alpha: 0.22)
                      : AxisColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isChecked ? AxisColors.success : AxisColors.borderSubtle,
                    width: 1.3,
                  ),
                ),
                child: isChecked
                    ? Icon(Icons.check_rounded, size: iconSize, color: AxisColors.success)
                    : null,
              ),
              Expanded(
                child: Text.rich(
                  _parseInlineSpans(
                    text,
                    base: TextStyle(
                      color: isChecked ? AxisColors.textDim : AxisColors.textHigh,
                      fontSize: 13.5 * widget.fontScale,
                      height: 1.35,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      decorationColor: AxisColors.textDim,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderedListItem(BuildContext context, String number, String text) {
    final badgeFontSize = (10 * widget.fontScale).clamp(9.0, 14.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: AxisColors.secondary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: AxisColors.secondary.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: AxisColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: badgeFontSize,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              _parseInlineSpans(
                text,
                base: TextStyle(
                  color: AxisColors.textHigh,
                  fontSize: 13.5 * widget.fontScale,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletListItem(BuildContext context, String text) {
    final dotSize = (6 * widget.fontScale).clamp(5.0, 10.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6 * widget.fontScale, right: 9),
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: AxisColors.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AxisColors.secondary.withValues(alpha: 0.5),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          Expanded(
            child: Text.rich(
              _parseInlineSpans(
                text,
                base: TextStyle(
                  color: AxisColors.textHigh,
                  fontSize: 13.5 * widget.fontScale,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Text.rich(
        _parseInlineSpans(
          text,
          base: TextStyle(
            color: AxisColors.textHigh,
            fontSize: 13.5 * widget.fontScale,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBlock(BuildContext context, String code) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12 * widget.fontScale,
          color: const Color(0xFF7DD3FC), // Cyber cyan
          height: 1.35,
        ),
      ),
    );
  }

  /// Parses inline formatting: **bold**, *italic*, `code`, ~~strike~~
  static TextSpan _parseInlineSpans(String raw, {required TextStyle base}) {
    final spans = <InlineSpan>[];
    // Regex matching:
    // 1: `code`
    // 2: **bold**
    // 3: *italic*
    // 4: ~~strike~~
    final regex = RegExp(r'(`([^`]+)`)'
        r'|(\*\*([^*]+)\*\*)'
        r'|(\*([^*]+)\*)'
        r'|(~~([^~]+)~~)');

    int lastIndex = 0;
    for (final match in regex.allMatches(raw)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: raw.substring(lastIndex, match.start),
          style: base,
        ));
      }

      if (match.group(2) != null) {
        // Inline code
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Text(
              match.group(2)!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: (base.fontSize ?? 13) * 0.9,
                color: AxisColors.secondary,
              ),
            ),
          ),
        ));
      } else if (match.group(4) != null) {
        // Bold
        spans.add(TextSpan(
          text: match.group(4)!,
          style: base.copyWith(
            fontWeight: FontWeight.bold,
            color: AxisColors.textHigh,
          ),
        ));
      } else if (match.group(6) != null) {
        // Italic
        spans.add(TextSpan(
          text: match.group(6)!,
          style: base.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (match.group(8) != null) {
        // Strike
        spans.add(TextSpan(
          text: match.group(8)!,
          style: base.copyWith(
            decoration: TextDecoration.lineThrough,
            color: AxisColors.textDim,
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < raw.length) {
      spans.add(TextSpan(
        text: raw.substring(lastIndex),
        style: base,
      ));
    }

    return TextSpan(children: spans);
  }
}
