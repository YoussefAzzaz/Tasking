import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/text_direction.dart';

/// Cyber-minimalist search bar matching Axis Obsidian Kinetic design system.
/// Features glassmorphism background, smooth focus borders, and an animated clear button.
class CyberSearchBar extends StatefulWidget {
  const CyberSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.accentColor = AxisColors.secondary,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final Color accentColor;

  @override
  State<CyberSearchBar> createState() => _CyberSearchBarState();
}

class _CyberSearchBarState extends State<CyberSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 42,
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFocused
              ? widget.accentColor.withValues(alpha: 0.65)
              : AxisColors.borderSubtle,
          width: _isFocused ? 1.2 : 1.0,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: AutoDirectionScope(
        controller: widget.controller,
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: const TextStyle(
            color: AxisColors.textHigh,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: widget.accentColor,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              color: AxisColors.textDim,
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: _isFocused ? widget.accentColor : AxisColors.textDim,
            ),
            suffixIcon: hasText
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: AxisColors.textDim,
                    splashRadius: 16,
                    tooltip: 'Clear search',
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged?.call('');
                      widget.onClear?.call();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          ),
          onChanged: (val) {
            setState(() {});
            widget.onChanged?.call(val);
          },
        ),
      ),
    );
  }
}
