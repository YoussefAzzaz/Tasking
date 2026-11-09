import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Regular expression matching Unicode ranges for Arabic scripts:
/// - Arabic (0600–06FF)
/// - Arabic Supplement (0750–077F)
/// - Arabic Extended-A (08A0–08FF)
/// - Arabic Presentation Forms-A (FB50–FDFF)
/// - Arabic Presentation Forms-B (FE70–FEFF)
final RegExp _arabicRegex = RegExp(
  r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
);

/// Regular expression matching standard Latin alphabetic characters.
final RegExp _latinRegex = RegExp(r'[a-zA-Z]');

/// Detects if the given [text] is primarily Arabic or should be formatted as RTL.
///
/// Returns `true` if:
/// 1. The first strong directional character is RTL/Arabic (standard Unicode Bidi algorithm).
/// 2. Or the text contains Arabic characters and Arabic characters outnumber or equal Latin characters.
bool isArabicText(String? text) {
  if (text == null || text.trim().isEmpty) return false;

  // 1. Unicode BiDi check for first strong directional character
  if (Bidi.detectRtlDirectionality(text)) {
    return true;
  }

  // 2. Character ratio fallback for mixed strings with short Latin prefixes
  // Sample up to first 150 characters to prevent expensive scanning of huge markdown files
  final sample = text.length > 150 ? text.substring(0, 150) : text;
  final arabicMatches = _arabicRegex.allMatches(sample).length;
  if (arabicMatches > 0) {
    final latinMatches = _latinRegex.allMatches(sample).length;
    if (arabicMatches >= latinMatches) {
      return true;
    }
  }

  return false;
}

/// Resolves the [TextDirection] for a given [text], defaulting to [defaultDirection].
TextDirection getTextDirection(
  String? text, {
  TextDirection defaultDirection = TextDirection.ltr,
}) {
  return isArabicText(text) ? TextDirection.rtl : defaultDirection;
}

/// Resolves the appropriate [TextAlign] for a given [text].
TextAlign getTextAlign(
  String? text, {
  TextAlign defaultAlign = TextAlign.start,
  TextAlign? rtlAlign,
  TextAlign? ltrAlign,
}) {
  if (isArabicText(text)) {
    return rtlAlign ?? TextAlign.right;
  }
  return ltrAlign ?? defaultAlign;
}

/// String extension for convenient Arabic & RTL helpers.
extension ArabicTextDirectionExt on String? {
  /// Returns `true` if this string contains predominantly Arabic or RTL content.
  bool get isArabic => isArabicText(this);

  /// Returns `TextDirection.rtl` if Arabic, otherwise `TextDirection.ltr`.
  TextDirection get textDirection => getTextDirection(this);

  /// Returns `TextAlign.right` if Arabic, otherwise `TextAlign.left` or `TextAlign.start`.
  TextAlign get textAlign => getTextAlign(this);
}

/// A widget that automatically wraps [child] with a [Directionality]
/// widget based on the detected direction of [text].
class AutoDirection extends StatelessWidget {
  const AutoDirection({
    super.key,
    required this.text,
    required this.child,
    this.defaultDirection,
  });

  final String text;
  final Widget child;
  final TextDirection? defaultDirection;

  @override
  Widget build(BuildContext context) {
    final isRtl = isArabicText(text);
    final direction = isRtl
        ? TextDirection.rtl
        : (defaultDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr);

    return Directionality(
      textDirection: direction,
      child: child,
    );
  }
}

/// A reactive wrapper for text input controllers that dynamically updates
/// [Directionality] to RTL as the user enters Arabic characters, and back to
/// LTR when cleared or when typing Latin text.
class AutoDirectionScope extends StatefulWidget {
  const AutoDirectionScope({
    super.key,
    required this.controller,
    required this.child,
    this.hintText,
    this.defaultDirection,
    this.onDirectionChanged,
  });

  final TextEditingController controller;
  final Widget child;
  final String? hintText;
  final TextDirection? defaultDirection;
  final ValueChanged<bool>? onDirectionChanged;

  @override
  State<AutoDirectionScope> createState() => _AutoDirectionScopeState();
}

class _AutoDirectionScopeState extends State<AutoDirectionScope> {
  late bool _isArabic;

  @override
  void initState() {
    super.initState();
    _isArabic = _resolveIsArabic();
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant AutoDirectionScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
      final newIsArabic = _resolveIsArabic();
      if (newIsArabic != _isArabic) {
        _isArabic = newIsArabic;
        widget.onDirectionChanged?.call(_isArabic);
      }
    } else if (oldWidget.hintText != widget.hintText && widget.controller.text.isEmpty) {
      final newIsArabic = _resolveIsArabic();
      if (newIsArabic != _isArabic) {
        _isArabic = newIsArabic;
        widget.onDirectionChanged?.call(_isArabic);
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  bool _resolveIsArabic() {
    final text = widget.controller.text;
    if (text.trim().isNotEmpty) {
      return isArabicText(text);
    }
    if (widget.hintText != null && widget.hintText!.trim().isNotEmpty) {
      return isArabicText(widget.hintText);
    }
    return false;
  }

  void _handleTextChange() {
    final newIsArabic = _resolveIsArabic();
    if (newIsArabic != _isArabic) {
      setState(() {
        _isArabic = newIsArabic;
      });
      widget.onDirectionChanged?.call(_isArabic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final direction = _isArabic
        ? TextDirection.rtl
        : (widget.defaultDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr);

    return Directionality(
      textDirection: direction,
      child: widget.child,
    );
  }
}

/// A drop-in replacement for [Text] that automatically sets its [textDirection]
/// and [textAlign] based on whether the string is Arabic.
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(
    this.text, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String text;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final isArabic = isArabicText(text);
    final resolvedDirection = textDirection ?? (isArabic ? TextDirection.rtl : null);
    final resolvedAlign = textAlign ?? (isArabic ? TextAlign.start : null);

    final textWidget = Text(
      text,
      style: style,
      strutStyle: strutStyle,
      textAlign: resolvedAlign,
      textDirection: resolvedDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );

    if (isArabic && textDirection == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: textWidget,
      );
    }

    return textWidget;
  }
}
