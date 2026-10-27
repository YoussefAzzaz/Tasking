import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/desktop/desktop_command_center.dart';
import 'package:axis/ui/desktop/widgets/confirm_dialog.dart';
import 'package:axis/ui/desktop/widgets/undo_snackbar.dart';

/// Phase 1 (Trust & Safety) regression tests:
/// 1. No fabricated telemetry is rendered anywhere in the desktop shell.
/// 2. ConfirmDialog resolves strictly (confirm=true, cancel/esc/enter=false).
/// 3. Undo snackbar invokes its restore callback.
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

  group('Phase 1 — honest telemetry', () {
    testWidgets('renders no fabricated metrics on the desktop shell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();
      await tester.pump();

      // Fabricated values must be gone.
      expect(find.text('2h 45m'), findsNothing);
      expect(find.textContaining('CORE PRO'), findsNothing);
      expect(find.text('INTEGRITY OK'), findsNothing);
      expect(find.text('All Systems Online'), findsNothing);
      expect(find.textContaining('1,280 rows'), findsNothing);
      expect(find.text('18.4 MB'), findsNothing);

      // Real values: focus metric falls back to 0m without a database.
      expect(find.text('FOCUS TODAY'), findsOneWidget);
      expect(find.text('0m'), findsOneWidget);
    });
  });

  group('Phase 1 — ConfirmDialog', () {
    testWidgets('resolves true when the destructive action is confirmed', (
      tester,
    ) async {
      final result = await openDialog(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result.value, isTrue);
    });

    testWidgets('resolves false on Cancel', (tester) async {
      final result = await openDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result.value, isFalse);
    });

    testWidgets('resolves false on Escape key', (tester) async {
      final result = await openDialog(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(result.value, isFalse);
    });

    testWidgets('resolves false on Enter key (safe default)', (tester) async {
      final result = await openDialog(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(result.value, isFalse);
    });
  });

  group('Phase 1 — Undo snackbar', () {
    testWidgets('UNDO action invokes the restore callback', (tester) async {
      bool undone = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showUndoSnackBar(
                      context,
                      message: 'Task deleted',
                      onUndo: () async => undone = true,
                    );
                  },
                  child: const Text('delete'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('delete'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Task deleted'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();
      expect(undone, isTrue);
    });
  });
}
