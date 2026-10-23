import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/habits/widgets/habit_category_card.dart';
import 'package:axis/ui/habits/create_habit_sheet.dart';
import 'package:axis/ui/tasks/project_big_task_card.dart';
import 'package:axis/ui/tasks/inbox_tab.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';

class _FakeTaskRepo extends TaskRepository {
  final _controller = StreamController<List<Task>>.broadcast();

  @override
  Stream<List<Task>> watchTasks() => _controller.stream;

  void emit(List<Task> tasks) => _controller.add(tasks);
  void dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expand/Shrink Animation Tests', () {
    testWidgets('HabitCategoryCard includes AnimatedRotation and AnimatedSize for smooth toggle', (tester) async {
      final habits = [
        Habit(id: 'h1', name: 'Read Quran', scheduleType: 'daily', isDoneToday: false),
        Habit(id: 'h2', name: 'Gym Workout', scheduleType: 'daily', isDoneToday: true),
      ];
      final category = const HabitCategory(id: 'cat_health', name: 'Health & Deen', icon: 'health');

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HabitCategoryCard(
                category: category,
                color: Colors.green,
                habits: habits,
                onToggleHabit: (id, done) {},
                onEditHabit: (_) {},
                onDeleteHabit: (_) {},
                onAddHabit: () {},
              ),
            ),
          ),
        ),
      );

      // Verify AnimatedRotation and AnimatedSize exist in the widget hierarchy
      expect(find.byType(AnimatedRotation), findsOneWidget);
      expect(find.byType(AnimatedSize), findsOneWidget);
      expect(find.text('Read Quran'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Health & Deen'));
      await tester.pump(); // start animation
      await tester.pump(const Duration(milliseconds: 150)); // mid-animation
      await tester.pumpAndSettle(); // finish animation

      // When collapsed, AnimatedRotation turns to 0.0 and habits list shrinks
      final rotation = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(0.0));
      expect(find.text('Read Quran'), findsNothing);

      // Tap again to expand
      await tester.tap(find.text('Health & Deen'));
      await tester.pump();
      await tester.pumpAndSettle();

      final expandedRotation = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(expandedRotation.turns, equals(0.5));
      expect(find.text('Read Quran'), findsOneWidget);
    });

    testWidgets('ProjectBigTaskCard includes AnimatedRotation and AnimatedSize for smooth toggle', (tester) async {
      final project = Project(id: 'proj_1', name: 'Alpha Release', color: '#6366F1');
      final subtasks = [
        Task(id: 't1', title: 'Setup CI/CD Pipeline', status: 'todo'),
        Task(id: 't2', title: 'Deploy Staging', status: 'done'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectBigTaskCard(
                project: project,
                color: Colors.indigo,
                subtasks: subtasks,
                taskRepo: TaskRepository(),
                projectRepo: ProjectRepository(),
                onAddSubtask: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedRotation), findsOneWidget);
      expect(find.byType(AnimatedSize), findsOneWidget);
      expect(find.text('Setup CI/CD Pipeline'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Alpha Release'));
      await tester.pump();
      await tester.pumpAndSettle();

      final rotation = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(rotation.turns, equals(0.0));
      expect(find.text('Setup CI/CD Pipeline'), findsNothing);

      // Tap again to expand
      await tester.tap(find.text('Alpha Release'));
      await tester.pump();
      await tester.pumpAndSettle();

      final expandedRotation = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
      expect(expandedRotation.turns, equals(0.5));
      expect(find.text('Setup CI/CD Pipeline'), findsOneWidget);
    });
  });

  group('InboxTab Today Filtering Tests', () {
    testWidgets('InboxTab displays only today tasks (both done and todo), excluding other dates', (tester) async {
      final repo = _FakeTaskRepo();
      final filterNotifier = ValueNotifier<TaskFilterCriteria>(const TaskFilterCriteria());
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));

      final allTasks = [
        Task(id: 't_today_todo', title: 'Today Pending Task', dueDate: todayStr, status: 'todo'),
        Task(id: 't_today_done', title: 'Today Finished Task', dueDate: todayStr, status: 'done'),
        Task(id: 't_yesterday', title: 'Yesterday Task', dueDate: yesterdayStr, status: 'todo'),
        Task(id: 't_tomorrow', title: 'Tomorrow Task', dueDate: tomorrowStr, status: 'todo'),
        Task(id: 't_no_date', title: 'No Date Task', dueDate: null, status: 'todo'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: InboxTab(
              repo: repo,
              filterCriteria: filterNotifier,
            ),
          ),
        ),
      );

      repo.emit(allTasks);
      await tester.pump();

      // Only today's tasks should be rendered (both todo and done)
      expect(find.text('Today Pending Task'), findsOneWidget);
      expect(find.text('Today Finished Task'), findsOneWidget);

      // Tasks from other dates or no date must not appear in Inbox
      expect(find.text('Yesterday Task'), findsNothing);
      expect(find.text('Tomorrow Task'), findsNothing);
      expect(find.text('No Date Task'), findsNothing);

      repo.dispose();
    });
  });

  group('CreateHabitSheet Non-Daily Frequency Tests', () {
    testWidgets('Switching frequency to weekly shows optional time without forcing time input', (tester) async {
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

      // Initially Daily with required time
      expect(find.text('TIME *'), findsOneWidget);

      // Tap Frequency dropdown and select Weekly
      await tester.tap(find.text('Daily (00:00)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Weekly (Fri)').last);
      await tester.pumpAndSettle();

      // Time should now be optional and set to Anytime (not requiring exact time)
      expect(find.text('TIME (OPTIONAL)'), findsOneWidget);
      expect(find.text('Anytime'), findsOneWidget);
      expect(find.text('Non-daily habits do not require an exact time of day.'), findsOneWidget);
    });
  });

  group('CreateTaskSheet Duration Timer Picker Tests', () {
    testWidgets('CreateTaskSheet replaces clock with duration timer and quick presets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateTaskSheet(
              onTaskCreated: () {},
            ),
          ),
        ),
      );

      // Verify timer labels and preset chips exist
      expect(find.text('TASK DURATION (TIMER)'), findsOneWidget);
      expect(find.text('Set Timer'), findsOneWidget);
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('30m'), findsOneWidget);

      // Tapping 15m preset sets it and shows micro-slot badge
      await tester.ensureVisible(find.text('15m'));
      await tester.tap(find.text('15m'));
      await tester.pumpAndSettle();

      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('TIMER (≤15M MICRO)'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);

      // Tapping 30m preset changes duration to 30 min (non-micro)
      await tester.ensureVisible(find.text('30m'));
      await tester.tap(find.text('30m'));
      await tester.pumpAndSettle();

      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('TASK DURATION (TIMER)'), findsOneWidget);
    });
  });
}
