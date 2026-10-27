import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';

/// Semantic role used to map a pressable control onto accessibility APIs.
enum DesktopPressableRole { button, checkbox, tab, listItem }

/// Visual state handed to [DesktopPressable.builder] on every change so each
/// control can integrate hover/press/focus into its own decoration.
class DesktopPressableVisuals {
  const DesktopPressableVisuals({
    this.hovered = false,
    this.focused = false,
    this.pressed = false,
  });

  final bool hovered;
  final bool focused;
  final bool pressed;
}

/// Shared interaction core for all Axis desktop controls.
///
/// Wraps the child in one focusable, hover-tracking, keyboard-activating
/// surface: pointer click, Enter, Space, and numpad-Enter all trigger
/// [onActivate]. Semantics are derived from [role], [checked], [selected], and
/// [label]; an optional themed [tooltip] wraps the control.
///
/// The focus ring is intentionally left to the builder (via
/// [desktopFocusRing]) so each control can merge it with its own shadows
/// without layout shift.
class DesktopPressable extends StatefulWidget {
  const DesktopPressable({
    super.key,
    required this.builder,
    required this.onActivate,
    this.enabled = true,
    this.role = DesktopPressableRole.button,
    this.label,
    this.checked,
    this.selected,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
    this.focusable = true,
    this.mouseCursor = SystemMouseCursors.click,
  });

  /// Builds the visible control. Called on every hover/press/focus change.
  final Widget Function(BuildContext context, DesktopPressableVisuals visuals)
  builder;

  /// Fired on pointer tap, Enter, Space, and numpad-Enter.
  final VoidCallback? onActivate;

  final bool enabled;
  final DesktopPressableRole role;

  /// Semantic label (e.g. for icon-only controls).
  final String? label;
  final bool? checked;
  final bool? selected;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Set false for chrome that should be skipped by keyboard traversal
  /// (e.g. window control buttons, mirroring native titlebar behavior).
  final bool focusable;
  final MouseCursor mouseCursor;

  @override
  State<DesktopPressable> createState() => _DesktopPressableState();
}

class _DesktopPressableState extends State<DesktopPressable> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _enabled => widget.enabled && widget.onActivate != null;

  void _activate() {
    if (_enabled) widget.onActivate!();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _buildSemantics(
      Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => _activate(),
            ),
          },
          child: Focus(
            canRequestFocus: false,
            descendantsAreFocusable: _enabled && widget.focusable,
            descendantsAreTraversable: _enabled && widget.focusable,
            child: FocusableActionDetector(
              focusNode: widget.focusNode,
              autofocus: widget.enabled && widget.autofocus,
              enabled: _enabled,
              mouseCursor: _enabled
                  ? widget.mouseCursor
                  : SystemMouseCursors.basic,
              onShowHoverHighlight: (value) => setState(() => _hovered = value),
              onShowFocusHighlight: (value) => setState(() => _focused = value),
              child: Listener(
                onPointerDown: (_) => setState(() => _pressed = true),
                onPointerUp: (_) => setState(() => _pressed = false),
                onPointerCancel: (_) => setState(() => _pressed = false),
                child: GestureDetector(
                  onTap: _enabled ? _activate : null,
                  child: widget.builder(
                    context,
                    DesktopPressableVisuals(
                      hovered: _hovered,
                      focused: _focused,
                      pressed: _pressed,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      child = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        textStyle: GoogleFonts.getFont(
          'Geist',
          fontSize: 11,
          color: AxisColors.textHigh,
        ),
        decoration: BoxDecoration(
          color: AxisColors.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AxisColors.borderGlass2, width: 1),
        ),
        child: child,
      );
    }

    return child;
  }

  Widget _buildSemantics(Widget child) {
    switch (widget.role) {
      case DesktopPressableRole.checkbox:
        return Semantics(
          enabled: _enabled,
          checked: widget.checked ?? false,
          label: widget.label,
          child: child,
        );
      case DesktopPressableRole.tab:
      case DesktopPressableRole.listItem:
        return Semantics(
          button: true,
          enabled: _enabled,
          selected: widget.selected ?? false,
          label: widget.label,
          child: child,
        );
      case DesktopPressableRole.button:
        return Semantics(
          button: true,
          enabled: _enabled,
          label: widget.label,
          child: child,
        );
    }
  }
}

/// Shared focus indicator: a 2px emissive halo drawn outside the control.
/// Merge the returned list into the control's `boxShadow` — no layout shift.
List<BoxShadow> desktopFocusRing(bool focused, {Color? color}) {
  if (!focused) return const [];
  return [
    BoxShadow(
      color: (color ?? AxisColors.primarySoft).withValues(alpha: 0.45),
      blurRadius: 0,
      spreadRadius: 2,
    ),
  ];
}
