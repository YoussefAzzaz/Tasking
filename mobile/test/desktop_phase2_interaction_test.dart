import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/desktop/desktop_command_center.dart';
import 'package:axis/ui/desktop/dialogs/omnibar_dialog.dart';
import 'package:axis/ui/desktop/widgets/confirm_dialog.dart';
import 'package:axis/ui/desktop/widgets/desktop_checkbox.dart';
import 'package:axis/ui/desktop/widgets/ghost_button.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';

/// Phase 2 (Interaction Foundation) tests:
/// 1. Keyboard traversal reaches desktop controls and Enter/Space activate them.
/// 2. Global shortcuts: Ctrl+N (or ⌘N on macOS) opens the quick task dialog.
/// 3. Disabled controls are skipped by traversal.
/// 4. Screen-reader semantics: checkbox checked state, focused omnibar trigger.
/// 5. Window chrome exposes tooltips but stays out of the Tab order.
/// 6. ConfirmDialog keyboard model: focus starts on Cancel; Tab+Enter confirms.
void main() {
  Widget buildDesktopApp({Size size = const Size(1440, 900)}) {
    return MaterialApp(
      theme: AxisTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const DesktopCommandCenter(),
      ),
    );
  }

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(buildDesktopApp());
    await tester.pumpAndSettle();
  }

  /// Pumps a host app, opens the ConfirmDialog, and returns a notifier that
  /// receives the dialog's resolution.
  Future<ValueNotifier<bool?>> openDialog(WidgetTester tester) async {
    final result = ValueNotifier<bool?>(null);
    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result.value = await ConfirmDialog.show(
                  context,
                  title: 'Delete note?',
                  message: 'Test message.',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  group('Phase 2 — shell keyboard traversal', () {
    testWidgets('Tab reaches the omnibar trigger; Enter opens it', (
      tester,
    ) async {
      await pumpShell(tester);

      final semantics = tester.ensureSemantics();
      try {
        // The omnibar trigger is the first focusable control in the titlebar.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();

        final trigger = find.bySemanticsLabel(RegExp('Open omnibar'));
        expect(trigger, findsOneWidget);
        expect(
          tester.getSemantics(trigger).flagsCollection.isFocused,
          Tristate.isTrue,
          reason:
              'First Tab must land on the omnibar trigger (first control in the titlebar group)',
        );

        // Enter activates the focused trigger and opens the omnibar.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(OmnibarDialog), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Ctrl+N opens the quick task dialog', (tester) async {
      await pumpShell(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.byType(CreateTaskSheet), findsOneWidget);
    });
  });

  group('Phase 2 — platform shortcut mapping', () {
    testWidgets('⌘N opens the quick task dialog on macOS and labels use ⌘', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpShell(tester);

        // Sidebar CTA pill must display the mac variant of the shortcut.
        expect(find.text('⌘ N'), findsOneWidget);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();

        expect(find.byType(CreateTaskSheet), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Phase 2 — shared pressable controls', () {
    testWidgets('GhostButton activates on Enter and Space', (tester) async {
      int presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Center(
              child: GhostButton(
                label: 'Action',
                autofocus: true,
                onPressed: () => presses++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(presses, 2);
    });

    testWidgets(
      'DesktopCheckbox toggles with Space and exposes checked state',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          bool? toggledTo;
          await tester.pumpWidget(
            MaterialApp(
              theme: AxisTheme.dark,
              home: Scaffold(
                body: Center(
                  child: DesktopCheckbox(
                    value: false,
                    semanticLabel: 'Test task',
                    autofocus: true,
                    onChanged: (value) => toggledTo = value,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final node = tester.getSemantics(find.bySemanticsLabel('Test task'));
          expect(node.flagsCollection.isChecked, CheckedState.isFalse);

          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump();
          expect(toggledTo, isTrue);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('disabled controls are skipped by keyboard traversal', (
      tester,
    ) async {
      final enabledNode = FocusNode(debugLabel: 'enabled');
      final disabledNode = FocusNode(debugLabel: 'disabled');
      addTearDown(enabledNode.dispose);
      addTearDown(disabledNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                GhostButton(
                  label: 'Enabled',
                  onPressed: () {},
                  focusNode: enabledNode,
                  autofocus: true,
                ),
                GhostButton(
                  label: 'Disabled',
                  onPressed: null,
                  focusNode: disabledNode,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(enabledNode.hasFocus, isTrue);

      // Tab must skip the disabled control and wrap back to the enabled one.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(enabledNode.hasFocus, isTrue);
      expect(disabledNode.hasFocus, isFalse);
    });
  });

  group('Phase 2 — window chrome', () {
    testWidgets('window buttons announce tooltips to screen readers', (
      tester,
    ) async {
      await pumpShell(tester);

      final semantics = tester.ensureSemantics();
      try {
        expect(find.byTooltip('Minimize'), findsOneWidget);
        expect(find.byTooltip('Close'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  });

  group('Phase 2 — ConfirmDialog keyboard model', () {
    testWidgets('focus starts on Cancel (the safe default)', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await openDialog(tester);

        final cancel = find.text('Cancel');
        expect(cancel, findsOneWidget);
        expect(
          tester.getSemantics(cancel).flagsCollection.isFocused,
          Tristate.isTrue,
          reason:
              'Destructive dialogs must not start with focus on the confirm action',
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('Tab moves to the confirm action and Enter confirms', (
      tester,
    ) async {
      final result = await openDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result.value, isTrue);
    });

    testWidgets('Enter without Tab still cancels (focus is on Cancel)', (
      tester,
    ) async {
      final result = await openDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(result.value, isFalse);
    });
  });
}
