import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard shortcuts registered globally across the Axis desktop experience.
abstract final class DesktopShortcuts {
  static const newTask = SingleActivator(LogicalKeyboardKey.keyN, control: true);
  static const omnibar = SingleActivator(LogicalKeyboardKey.keyK, control: true);
  static const tab1    = SingleActivator(LogicalKeyboardKey.digit1, control: true);
  static const tab2    = SingleActivator(LogicalKeyboardKey.digit2, control: true);
  static const tab3    = SingleActivator(LogicalKeyboardKey.digit3, control: true);
  static const tab4    = SingleActivator(LogicalKeyboardKey.digit4, control: true);
  static const tab5    = SingleActivator(LogicalKeyboardKey.digit5, control: true);
  static const tab6    = SingleActivator(LogicalKeyboardKey.digit6, control: true);
  static const tab7    = SingleActivator(LogicalKeyboardKey.digit7, control: true);
}
