import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/ui/habits/create_habit_sheet.dart';

void main() {
  testWidgets('CreateHabitSheet renders on narrow screens without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: CreateHabitSheet(
            onHabitCreated: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('NEW HABIT ROUTINE'), findsOneWidget);
    expect(find.text('HABIT NAME *'), findsOneWidget);
    expect(find.text('ACTIVATE HABIT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CreateHabitSheet renders in edit mode on 320px ultra-compact screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final habit = Habit(
      id: 'h_1',
      name: 'Deep Reading 40 Pages',
      category: 'Focus',
      icon: 'book',
      color: '#38BDF8',
      scheduleType: 'weekly',
      remindTime: '08:30 PM',
      targetValue: 30,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: CreateHabitSheet(
            habitToEdit: habit,
            onHabitCreated: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('EDIT HABIT ROUTINE'), findsOneWidget);
    expect(find.text('UPDATE HABIT'), findsOneWidget);
    expect(find.text('DELETE HABIT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CreateHabitSheet handles keyboard viewInsets without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: CreateHabitSheet(
            onHabitCreated: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('NEW HABIT ROUTINE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
