import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';
import 'package:axis/ui/habits/widgets/habit_category_card.dart';

void main() {
  testWidgets('HabitCategoryCard renders generic habits without overflow on compact screen',
      (WidgetTester tester) async {
    // Set a narrow screen size (360x740) typical of compact Android phones
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const workoutCategory = HabitCategory(
      id: 'cat_workout',
      name: 'Workout',
      icon: 'fitness',
      color: '#10B981',
    );

    final workoutHabits = [
      Habit(
        id: 'habit_pushups',
        name: 'Morning Pushups',
        category: 'Workout',
        icon: 'fitness',
        remindTime: '07:00 AM',
        isDoneToday: false,
      ),
      Habit(
        id: 'habit_running',
        name: 'Evening 5km Run',
        category: 'Workout',
        icon: 'fitness',
        remindTime: '06:30 PM',
        isDoneToday: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: HabitCategoryCard(
                category: workoutCategory,
                color: const Color(0xFF10B981),
                habits: workoutHabits,
                onToggleHabit: (habit, done) {},
                onEditHabit: (habit) {},
                onDeleteHabit: (habit) {},
                onAddHabit: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify key category widgets rendered
    expect(find.text('Workout'), findsOneWidget);
    expect(find.text('Morning Pushups'), findsOneWidget);
    expect(find.text('Evening 5km Run'), findsOneWidget);
    expect(find.text('Add Habit to Workout'), findsOneWidget);

    // No overflow exception was thrown
    expect(tester.takeException(), isNull);
  });

  testWidgets('HabitCategoryCard triggers onEditHabit and onDeleteHabit via options menu',
      (WidgetTester tester) async {
    const workoutCategory = HabitCategory(
      id: 'cat_workout',
      name: 'Workout',
      icon: 'fitness',
      color: '#10B981',
    );

    Habit? editedHabit;
    Habit? deletedHabit;

    final habit = Habit(
      id: 'habit_pushups',
      name: 'Morning Pushups',
      category: 'Workout',
      icon: 'fitness',
      remindTime: '07:00 AM',
      isDoneToday: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HabitCategoryCard(
              category: workoutCategory,
              color: const Color(0xFF10B981),
              habits: [habit],
              onToggleHabit: (h, done) {},
              onEditHabit: (h) => editedHabit = h,
              onDeleteHabit: (h) => deletedHabit = h,
              onAddHabit: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Open popup menu and select Edit Habit
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Edit Habit'), findsOneWidget);
    expect(find.text('Delete Habit'), findsOneWidget);

    await tester.tap(find.text('Edit Habit'));
    await tester.pumpAndSettle();
    expect(editedHabit?.id, equals('habit_pushups'));

    // 2. Open popup menu, select Delete Habit and confirm dialog
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Habit'));
    await tester.pumpAndSettle();

    expect(find.text('Delete "Morning Pushups"?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deletedHabit?.id, equals('habit_pushups'));
  });

  testWidgets('HabitCategoryCard toggling checkbox updates optimistic state and triggers callback',
      (WidgetTester tester) async {
    const workoutCategory = HabitCategory(
      id: 'cat_workout',
      name: 'Workout',
      icon: 'fitness',
      color: '#10B981',
    );

    Habit? toggledHabit;
    bool? toggledState;

    final habit = Habit(
      id: 'habit_pushups',
      name: 'Morning Pushups',
      category: 'Workout',
      icon: 'fitness',
      remindTime: '07:00 AM',
      isDoneToday: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HabitCategoryCard(
              category: workoutCategory,
              color: const Color(0xFF10B981),
              habits: [habit],
              onToggleHabit: (h, done) {
                toggledHabit = h;
                toggledState = done;
              },
              onEditHabit: (_) {},
              onDeleteHabit: (_) {},
              onAddHabit: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial state: 0 of 1 habits finished today
    expect(find.text('0 of 1 habits finished today'), findsOneWidget);

    // Tap on checkbox to complete habit
    final checkbox = find.byType(AxisCheckbox);
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pump();

    // Verify callback was invoked
    expect(toggledHabit?.id, equals('habit_pushups'));
    expect(toggledState, isTrue);

    // Verify UI updated optimistically to 1 of 1 habits finished today & DONE badges
    expect(find.text('1 of 1 habits finished today'), findsOneWidget);
    expect(find.text('DONE'), findsWidgets);
  });
}

