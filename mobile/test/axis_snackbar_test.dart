import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/axis_snackbar.dart';

void main() {
  testWidgets('AxisSnackBar displays high-contrast readable text with Obsidian styling', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AxisSnackBar.show(
                  context,
                  message: 'Task "Build Flutter App" deleted',
                  icon: Icons.delete_outline_rounded,
                );
              },
              child: const Text('Show SnackBar'),
            ),
          ),
        ),
      ),
    );

    // Tap button to trigger SnackBar
    await tester.tap(find.text('Show SnackBar'));
    await tester.pumpAndSettle();

    // Verify message is visible
    expect(find.text('Task "Build Flutter App" deleted'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    // Verify text style has high-contrast white text
    final textWidget = tester.widget<Text>(find.text('Task "Build Flutter App" deleted'));
    expect(textWidget.style?.color, equals(AxisColors.textHigh));

    // Verify SnackBar background is dark obsidian surface
    final snackBarWidget = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBarWidget.backgroundColor, equals(AxisColors.surfaceHigh));
    expect(snackBarWidget.behavior, equals(SnackBarBehavior.floating));
  });

  testWidgets('AxisSnackBar.showDeleted provides Undo action when callback given', (tester) async {
    bool undone = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AxisSnackBar.showDeleted(
                  context,
                  itemTitle: 'Morning Meditation',
                  itemType: 'Habit',
                  onUndo: () => undone = true,
                );
              },
              child: const Text('Delete Habit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete Habit'));
    await tester.pumpAndSettle();

    expect(find.text('Habit "Morning Meditation" deleted'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
  });
}

