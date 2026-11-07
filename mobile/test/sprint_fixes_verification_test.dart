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

import 'package:axis/data/habit_repository.dart';
import 'package:axis/ui/habits/widgets/habit_category_card.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';

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

    testWidgets('HabitCategoryCard hides toggle switch and habit icon for long habit names', (tester) async {
      const category = HabitCategory(
        id: 'cat_growth',
        name: 'Personal Growth',
        icon: 'book',
        color: '#10B981',
      );

      final habits = [
        Habit(
          id: 'habit_super_long_name',
          name: 'Read 30 pages of high performance habits and clean code architecture',
          category: 'Personal Growth',
          icon: 'book',
          remindTime: '08:00 AM',
          isDoneToday: false,
          isEnabled: true,
        ),
      ];

      await tester.pumpWidget(
        buildTestApp(
          HabitCategoryCard(
            category: category,
            color: const Color(0xFF10B981),
            habits: habits,
            onToggleHabit: (h, d) {},
            onEditHabit: (h) {},
            onDeleteHabit: (h) {},
            onAddHabit: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the habit name is displayed
      expect(find.text('Read 30 pages of high performance habits and clean code architecture'), findsOneWidget);

      // Verify NO Switch widget exists on the card
      expect(find.byType(Switch), findsNothing);

      // Verify options menu button exists
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    test('Habit.fromRow respects HabitRepository.isHabitPaused even if remote PowerSync syncs null', () {
      const habitId = 'test_habit_pause_retention';

      // 1. Initially habit is not paused
      final rowBefore = {
        'id': habitId,
        'name': 'Test Habit',
        'is_enabled': 1,
      };
      expect(Habit.fromRow(rowBefore).isEnabled, isTrue);

      // 2. Pause habit
      HabitRepository().toggleHabitEnabled(habitId, false);
      expect(HabitRepository.isHabitPaused(habitId), isTrue);

      // 3. Simulating PowerSync downloading from remote Supabase where is_enabled is NULL
      final rowFromSupabaseSync = {
        'id': habitId,
        'name': 'Test Habit',
        'is_enabled': null, // PowerSync wiped local value because remote had no is_enabled
      };
      // The habit MUST REMAIN PAUSED (isEnabled == false) and not get turned on again
      final habitAfterSync = Habit.fromRow(rowFromSupabaseSync);
      expect(habitAfterSync.isEnabled, isFalse);

      // 4. Unpause habit
      HabitRepository().toggleHabitEnabled(habitId, true);
      expect(HabitRepository.isHabitPaused(habitId), isFalse);
      expect(Habit.fromRow(rowFromSupabaseSync).isEnabled, isTrue);
    });
  });
}
