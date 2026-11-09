import 'package:flutter/material.dart';
import '../../../core/text_direction.dart';
import '../../../core/theme.dart';
import 'markdown_span_parser.dart';

/// Reusable block element builders for rendering Markdown components.
class MarkdownBlockBuilders {
  MarkdownBlockBuilders._();

  static Widget buildHeading(
    BuildContext context,
    String text, {
    required int level,
    required double fontScale,
  }) {
    double fontSize;
    Color color;
    FontWeight weight;
    double topPadding;

    switch (level) {
      case 1:
        fontSize = 19 * fontScale;
        color = AxisColors.textHigh;
        weight = FontWeight.bold;
        topPadding = 12;
        break;
      case 2:
        fontSize = 16 * fontScale;
        color = AxisColors.secondary;
        weight = FontWeight.bold;
        topPadding = 10;
        break;
      case 3:
      default:
        fontSize = 14 * fontScale;
        color = AxisColors.textHigh;
        weight = FontWeight.w600;
        topPadding = 8;
        break;
    }

    final isArabic = isArabicText(text);
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 4),
      child: Text.rich(
        MarkdownSpanParser.parseInlineSpans(
          text,
          base: TextStyle(
            fontSize: fontSize,
            fontWeight: weight,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
      ),
    );
  }

  static Widget buildBlockquote(
    BuildContext context,
    String text, {
    required double fontScale,
  }) {
    final isArabic = isArabicText(text);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.only(
          topLeft: isArabic ? const Radius.circular(8) : Radius.zero,
          bottomLeft: isArabic ? const Radius.circular(8) : Radius.zero,
          topRight: isArabic ? Radius.zero : const Radius.circular(8),
          bottomRight: isArabic ? Radius.zero : const Radius.circular(8),
        ),
        border: Border(
          left: isArabic
              ? BorderSide.none
              : const BorderSide(color: AxisColors.secondary, width: 3),
          right: isArabic
              ? const BorderSide(color: AxisColors.secondary, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Text.rich(
        MarkdownSpanParser.parseInlineSpans(
          text,
          base: TextStyle(
            color: AxisColors.textHigh.withValues(alpha: 0.9),
            fontStyle: FontStyle.italic,
            fontSize: 13 * fontScale,
            height: 1.4,
          ),
        ),
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
      ),
    );
  }

  static Widget buildChecklistItem(
    BuildContext context,
    String text, {
    required bool isChecked,
    VoidCallback? onToggle,
    required double fontScale,
  }) {
    final isArabic = isArabicText(text);
    final boxSize = (18 * fontScale).clamp(16.0, 26.0);
    final iconSize = (13 * fontScale).clamp(11.0, 19.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: Row(
            textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(
                  top: 2,
                  right: isArabic ? 0 : 9,
                  left: isArabic ? 9 : 0,
                ),
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  color: isChecked
                      ? AxisColors.success.withValues(alpha: 0.22)
                      : AxisColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        isChecked ? AxisColors.success : AxisColors.borderSubtle,
                    width: 1.3,
                  ),
                ),
                child: isChecked
                    ? Icon(Icons.check_rounded,
                        size: iconSize, color: AxisColors.success)
                    : null,
              ),
              Expanded(
                child: Text.rich(
                  MarkdownSpanParser.parseInlineSpans(
                    text,
                    base: TextStyle(
                      color:
                          isChecked ? AxisColors.textDim : AxisColors.textHigh,
                      fontSize: 13.5 * fontScale,
                      height: 1.35,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      decorationColor: AxisColors.textDim,
                    ),
                  ),
                  textDirection:
                      isArabic ? TextDirection.rtl : TextDirection.ltr,
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildOrderedListItem(
    BuildContext context,
    String number,
    String text, {
    required double fontScale,
  }) {
    final isArabic = isArabicText(text);
    final badgeFontSize = (10 * fontScale).clamp(9.0, 14.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 2,
              right: isArabic ? 0 : 8,
              left: isArabic ? 8 : 0,
            ),
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
              MarkdownSpanParser.parseInlineSpans(
                text,
                base: TextStyle(
                  color: AxisColors.textHigh,
                  fontSize: 13.5 * fontScale,
                  height: 1.35,
                ),
              ),
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildBulletListItem(
    BuildContext context,
    String text, {
    required double fontScale,
  }) {
    final isArabic = isArabicText(text);
    final dotSize = (6 * fontScale).clamp(5.0, 10.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              top: 6 * fontScale,
              right: isArabic ? 0 : 9,
              left: isArabic ? 9 : 0,
            ),
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
              MarkdownSpanParser.parseInlineSpans(
                text,
                base: TextStyle(
                  color: AxisColors.textHigh,
                  fontSize: 13.5 * fontScale,
                  height: 1.35,
                ),
              ),
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildParagraph(
    BuildContext context,
    String text, {
    required double fontScale,
  }) {
    final isArabic = isArabicText(text);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Text.rich(
        MarkdownSpanParser.parseInlineSpans(
          text,
          base: TextStyle(
            color: AxisColors.textHigh,
            fontSize: 13.5 * fontScale,
            height: 1.45,
          ),
        ),
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        textAlign: isArabic ? TextAlign.right : TextAlign.left,
      ),
    );
  }

  static Widget buildCodeBlock(
    BuildContext context,
    String code, {
    required double fontScale,
  }) {
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
          fontSize: 12 * fontScale,
          color: const Color(0xFF7DD3FC), // Cyber cyan
          height: 1.35,
        ),
      ),
    );
  }
}

