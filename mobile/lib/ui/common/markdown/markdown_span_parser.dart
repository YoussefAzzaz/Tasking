import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// Utility parser that converts raw text with inline markdown tokens
/// (**bold**, *italic*, `code`, ~~strike~~) into Flutter [TextSpan] trees.
class MarkdownSpanParser {
  MarkdownSpanParser._();

  static final RegExp _inlineTokenRegex = RegExp(
    r'(`([^`]+)`)'
    r'|(\*\*([^*]+)\*\*)'
    r'|(\*([^*]+)\*)'
    r'|(~~([^~]+)~~)',
  );

  /// Parses inline formatting: **bold**, *italic*, `code`, ~~strike~~
  static TextSpan parseInlineSpans(String raw, {required TextStyle base}) {
    final spans = <InlineSpan>[];

    int lastIndex = 0;
    for (final match in _inlineTokenRegex.allMatches(raw)) {
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

