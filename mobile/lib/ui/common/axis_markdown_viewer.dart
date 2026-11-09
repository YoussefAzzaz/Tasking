import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import 'markdown/markdown_block_builders.dart';

export 'markdown/markdown_block_builders.dart';
export 'markdown/markdown_span_parser.dart';

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
          blockWidgets.add(MarkdownBlockBuilders.buildCodeBlock(
            context,
            codeContent,
            fontScale: widget.fontScale,
          ));
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
        blockWidgets.add(MarkdownBlockBuilders.buildHeading(
          context,
          content,
          level: 1,
          fontScale: widget.fontScale,
        ));
        continue;
      }

      // Heading 2 (## ...)
      if (trimmed.startsWith('## ')) {
        final content = trimmed.substring(3).trim();
        blockWidgets.add(MarkdownBlockBuilders.buildHeading(
          context,
          content,
          level: 2,
          fontScale: widget.fontScale,
        ));
        continue;
      }

      // Heading 3 (### ...)
      if (trimmed.startsWith('### ')) {
        final content = trimmed.substring(4).trim();
        blockWidgets.add(MarkdownBlockBuilders.buildHeading(
          context,
          content,
          level: 3,
          fontScale: widget.fontScale,
        ));
        continue;
      }

      // Blockquote (> ...)
      if (trimmed.startsWith('> ') || trimmed == '>') {
        final content = trimmed.length > 2 ? trimmed.substring(2).trim() : '';
        blockWidgets.add(MarkdownBlockBuilders.buildBlockquote(
          context,
          content,
          fontScale: widget.fontScale,
        ));
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
          MarkdownBlockBuilders.buildChecklistItem(
            context,
            content,
            isChecked: isChecked,
            onToggle: () => _toggleChecklist(lineIndex),
            fontScale: widget.fontScale,
          ),
        );
        continue;
      }

      // Ordered list item (e.g. 1. or 12. ...)
      final orderedMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (orderedMatch != null) {
        final number = orderedMatch.group(1) ?? '1';
        final content = orderedMatch.group(2) ?? '';
        blockWidgets.add(MarkdownBlockBuilders.buildOrderedListItem(
          context,
          number,
          content,
          fontScale: widget.fontScale,
        ));
        continue;
      }

      // Unordered list / bullet point (-, *, • ...)
      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('• ')) {
        final content = trimmed.substring(2).trim();
        blockWidgets.add(MarkdownBlockBuilders.buildBulletListItem(
          context,
          content,
          fontScale: widget.fontScale,
        ));
        continue;
      }

      // Standard paragraph line
      blockWidgets.add(MarkdownBlockBuilders.buildParagraph(
        context,
        line,
        fontScale: widget.fontScale,
      ));
    }

    if (inCodeBlock && codeBlockLines.isNotEmpty) {
      blockWidgets.add(MarkdownBlockBuilders.buildCodeBlock(
        context,
        codeBlockLines.join('\n'),
        fontScale: widget.fontScale,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: blockWidgets,
    );
  }
}
