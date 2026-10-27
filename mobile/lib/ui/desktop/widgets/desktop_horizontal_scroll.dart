import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wraps any horizontal scrollable and translates vertical mouse-wheel scroll events
/// into horizontal scrolling so users don't have to hold Shift on desktop!
class DesktopHorizontalScroll extends StatefulWidget {
  const DesktopHorizontalScroll({
    super.key,
    required this.child,
    this.controller,
  });

  final Widget child;
  final ScrollController? controller;

  @override
  State<DesktopHorizontalScroll> createState() => _DesktopHorizontalScrollState();
}

class _DesktopHorizontalScrollState extends State<DesktopHorizontalScroll> {
  ScrollController? _internalController;
  ScrollController get _effectiveController =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (!_effectiveController.hasClients) return;
      final position = _effectiveController.position;
      if (position.maxScrollExtent <= 0) return;

      // Register with pointerSignalResolver to handle event before ancestor scrollables
      GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
        if (resolvedEvent is! PointerScrollEvent) return;
        if (!_effectiveController.hasClients) return;

        // If dy is non-zero (standard mouse wheel), use dy to scroll horizontally.
        // If dx is non-zero (Shift + scroll or trackpad horizontal pan), use dx.
        final delta = resolvedEvent.scrollDelta.dy != 0
            ? resolvedEvent.scrollDelta.dy
            : resolvedEvent.scrollDelta.dx;

        final newOffset = (_effectiveController.offset + delta).clamp(
          0.0,
          _effectiveController.position.maxScrollExtent,
        );
        _effectiveController.jumpTo(newOffset);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: widget.child,
    );
  }
}

/// A SingleChildScrollView configured with Axis.horizontal and automatic
/// desktop mouse-wheel scrolling without needing to hold Shift.
class DesktopHorizontalScrollView extends StatefulWidget {
  const DesktopHorizontalScrollView({
    super.key,
    required this.child,
    this.padding,
    this.physics,
    this.controller,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  State<DesktopHorizontalScrollView> createState() => _DesktopHorizontalScrollViewState();
}

class _DesktopHorizontalScrollViewState extends State<DesktopHorizontalScrollView> {
  ScrollController? _internalController;
  ScrollController get _effectiveController =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (!_effectiveController.hasClients) return;
      final position = _effectiveController.position;
      if (position.maxScrollExtent <= 0) return;

      GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
        if (resolvedEvent is! PointerScrollEvent) return;
        if (!_effectiveController.hasClients) return;

        final delta = resolvedEvent.scrollDelta.dy != 0
            ? resolvedEvent.scrollDelta.dy
            : resolvedEvent.scrollDelta.dx;

        final newOffset = (_effectiveController.offset + delta).clamp(
          0.0,
          _effectiveController.position.maxScrollExtent,
        );
        _effectiveController.jumpTo(newOffset);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: _effectiveController,
        padding: widget.padding,
        physics: widget.physics,
        child: widget.child,
      ),
    );
  }
}
