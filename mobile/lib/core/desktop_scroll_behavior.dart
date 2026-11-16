import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Custom desktop scroll behavior:
/// 1. Disables mouse-drag scrolling (mobile touch behavior) so clicking & dragging
///    with a mouse selects text or triggers gestures rather than dragging views.
/// 2. Enables horizontal scrolling with a standard mouse scroll wheel without
///    requiring the user to hold down the Shift key.
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    Widget content = child;

    // Attach desktop scrollbar safely only when a controller is attached
    if (details.controller != null) {
      switch (getPlatform(context)) {
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          content = RawScrollbar(
            controller: details.controller,
            child: content,
          );
          break;
        default:
          break;
      }
    }

    // If the scrollable is horizontal, allow vertical mouse wheel input
    // (scrollDelta.dy) to scroll the horizontal axis without requiring Shift.
    if (axisDirectionToAxis(details.direction) == Axis.horizontal) {
      content = _HorizontalMouseWheelScroll(
        details: details,
        child: content,
      );
    }

    return content;
  }
}

class _HorizontalMouseWheelScroll extends StatelessWidget {
  const _HorizontalMouseWheelScroll({
    required this.details,
    required this.child,
  });

  final ScrollableDetails details;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) return;
        if (event.kind != PointerDeviceKind.mouse) return;

        // If Shift is pressed or event already has non-zero dx, let Flutter's
        // native handler route it.
        if (event.scrollDelta.dy == 0 || event.scrollDelta.dx != 0) return;

        final controller = details.controller;
        if (controller == null || !controller.hasClients || controller.positions.length != 1) return;

        final position = controller.position;
        final delta = axisDirectionIsReversed(details.direction)
            ? -event.scrollDelta.dy
            : event.scrollDelta.dy;

        final target = (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );

        if (target != position.pixels) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {
            if (controller.hasClients) {
              controller.position.pointerScroll(delta);
            }
          });
        }
      },
      child: child,
    );
  }
}
