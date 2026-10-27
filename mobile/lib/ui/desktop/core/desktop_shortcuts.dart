import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keyboard shortcuts registered globally across the Axis desktop experience.
/// Apple platforms activate with ⌘ (meta); Windows/Linux with Ctrl.
abstract final class DesktopShortcuts {
  static bool get _apple => defaultTargetPlatform == TargetPlatform.macOS;

  static SingleActivator get newTask => _activator(LogicalKeyboardKey.keyN);
  static SingleActivator get omnibar => _activator(LogicalKeyboardKey.keyK);
  static SingleActivator get tab1 => _activator(LogicalKeyboardKey.digit1);
  static SingleActivator get tab2 => _activator(LogicalKeyboardKey.digit2);
  static SingleActivator get tab3 => _activator(LogicalKeyboardKey.digit3);
  static SingleActivator get tab4 => _activator(LogicalKeyboardKey.digit4);
  static SingleActivator get tab5 => _activator(LogicalKeyboardKey.digit5);
  static SingleActivator get tab6 => _activator(LogicalKeyboardKey.digit6);

  static SingleActivator _activator(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: _apple, control: !_apple);

  /// Display labels for shortcut pills (e.g. sidebar CTA, titlebar omnibar).
  static String get newTaskLabel => _apple ? '⌘ N' : 'Ctrl + N';
  static String get omnibarLabel => _apple ? '⌘ K' : 'Ctrl + K';
  static String tabLabel(int tabIndex) =>
      _apple ? '⌘ ${tabIndex + 1}' : 'Ctrl + ${tabIndex + 1}';
}
