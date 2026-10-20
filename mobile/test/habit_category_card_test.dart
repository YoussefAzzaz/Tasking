import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';
import 'package:axis/ui/habits/widgets/habit_category_card.dart';

void main() {
  testWidgets('HabitCategoryCard renders Prayers without overflow on compact screen',
      (WidgetTester tester) async {
    // Set a narrow screen size (360x740) typical of compact Android phones
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prayerCategory = const HabitCategory(
      id: 'cat_prayers',
      name: 'Prayers',
      icon: 'mosque',
      color: '#10B981',
    );

    final prayerHabits = [
      Habit(
        id: 'habit_prayer_fajr',
        name: 'Fajr Prayer',
        category: 'Prayers',
        icon: 'fajr',
        remindTime: '05:32',
        isDoneToday: false,
      ),
      Habit(
        id: 'habit_prayer_dhuhr',
        name: 'Dhuhr Prayer',
        category: 'Prayers',
        icon: 'dhuhr',
        remindTime: '12:45',
        isDoneToday: true,
      ),
      Habit(
        id: 'habit_prayer_asr',
        name: 'Asr Prayer',
        category: 'Prayers',
        icon: 'asr',
        remindTime: '16:05',
        isDoneToday: false,
      ),
      Habit(
        id: 'habit_prayer_maghrib',
        name: 'Maghrib Prayer',
        category: 'Prayers',
        icon: 'maghrib',
        remindTime: '18:50',
        isDoneToday: false,
      ),
      Habit(
        id: 'habit_prayer_isha',
        name: 'Isha Prayer',
        category: 'Prayers',
        icon: 'isha',
        remindTime: '20:15',
        isDoneToday: false,
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
                category: prayerCategory,
                color: const Color(0xFF10B981),
                habits: prayerHabits,
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

    // Verify key prayer widgets rendered
    expect(find.text('Prayers'), findsOneWidget);
    expect(find.text('Qibla Direction (Live GPS & Compass)'), findsOneWidget);
    expect(find.text('Adhan Alerts & Fajr Alarm'), findsOneWidget);
    expect(find.text('+1 MIN'), findsOneWidget);
    expect(find.text('Fajr Prayer'), findsOneWidget);
    expect(find.text('Adan 05:32'), findsOneWidget);

    // No overflow exception was thrown
    expect(tester.takeException(), isNull);
  });
}
