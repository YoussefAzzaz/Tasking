import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/shell/axis_bottom_bar.dart';
import 'package:axis/ui/notes/widgets/note_detail_sheet.dart';
import 'package:axis/ui/common/reading_font_size_control.dart';
import 'package:axis/ui/desktop/screens/command_deck_screen.dart';
import 'package:axis/ui/desktop/widgets/ghost_button.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: AxisTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );
  }

  group('Sprint Fixes Verification Tests', () {
    testWidgets('AxisBottomBar has Tasks at tab 0 and Habits at tab 1', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        buildTestApp(
          AxisBottomBar(
            selected: 0,
            onTap: (index) => tappedIndex = index,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find standard tabs
      final tasksTab = find.text('Tasks');
      final habitsTab = find.text('Habits');

      expect(tasksTab, findsOneWidget);
      expect(habitsTab, findsOneWidget);

      // Verify tapping tab 0 taps Tasks
      await tester.tap(tasksTab);
      expect(tappedIndex, equals(0));

      // Verify tapping tab 1 taps Habits
      await tester.tap(habitsTab);
      expect(tappedIndex, equals(1));
    });

    testWidgets('NoteDetailSheet has static ReadingFontSizeControl outside SingleChildScrollView', (tester) async {
      final note = Note(
        id: 'test-note-static-font',
        title: 'Long Note Title',
        bodyMd: 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5',
        category: 'note',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestApp(
          NoteDetailSheet(
            note: note,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReadingFontSizeControl), findsOneWidget);

      // Verify SingleChildScrollView exists for markdown content
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Verify ReadingFontSizeControl is NOT a descendant of SingleChildScrollView
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(ReadingFontSizeControl),
        ),
        findsNothing,
      );
    });

    testWidgets('CommandDeckScreen habit loop View button calls onNavigateToTab with 2 (Prayer & Habits)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int? navigatedTab;
      await tester.pumpWidget(
        buildTestApp(
          CommandDeckScreen(
            onNavigateToTab: (tab) => navigatedTab = tab,
            onOpenNewTaskDialog: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the GhostButton with label 'View ↗' in Streaks & Habit Loops card
      final viewButtons = find.widgetWithText(GhostButton, 'View ↗');
      expect(viewButtons, findsWidgets);

      // Tap View ↗ on the habit loops card
      await tester.tap(viewButtons.first);
      await tester.pumpAndSettle();

      expect(navigatedTab, equals(2)); // Tab 2 is Prayer & Habits
    });
  });
}
