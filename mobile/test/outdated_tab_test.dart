import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/outdated_tab.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';

class FakeTaskRepository extends TaskRepository {
  final StreamController<List<Task>> _controller = StreamController<List<Task>>.broadcast();

  void emit(List<Task> tasks) => _controller.add(tasks);

  @override
  Stream<List<Task>> watchTasks() => _controller.stream;

  void dispose() => _controller.close();
}

void main() {
  group('OutdatedTab Tests', () {
    late FakeTaskRepository fakeRepo;
    late ValueNotifier<TaskFilterCriteria> filterCriteria;

    setUp(() {
      fakeRepo = FakeTaskRepository();
      filterCriteria = ValueNotifier<TaskFilterCriteria>(const TaskFilterCriteria());
    });

    tearDown(() {
      fakeRepo.dispose();
      filterCriteria.dispose();
    });

    testWidgets('renders empty state when no tasks exist', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: OutdatedTab(
              repo: fakeRepo,
              filterCriteria: filterCriteria,
            ),
          ),
        ),
      );

      // Emit empty task list
      fakeRepo.emit([]);
      await tester.pumpAndSettle();

      expect(find.text('No Outdated or Finished Tasks'), findsOneWidget);
    });

    testWidgets('displays outdated and finished tasks in their respective sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: OutdatedTab(
              repo: fakeRepo,
              filterCriteria: filterCriteria,
            ),
          ),
        ),
      );

      final overdueTask = Task(
        id: 'task_overdue',
        title: 'Overdue Bugfix',
        dueDate: '2020-01-01',
        status: 'todo',
      );
      final finishedTask = Task(
        id: 'task_finished',
        title: 'Completed Feature',
        dueDate: '2026-10-20',
        status: 'done',
      );
      final upcomingTask = Task(
        id: 'task_upcoming',
        title: 'Future Feature',
        dueDate: '2099-01-01',
        status: 'todo',
      );

      fakeRepo.emit([overdueTask, finishedTask, upcomingTask]);
      await tester.pumpAndSettle();

      // Sections
      expect(find.text('OUTDATED'), findsOneWidget);
      expect(find.text('FINISHED'), findsOneWidget);

      // Tasks present
      expect(find.text('Overdue Bugfix'), findsOneWidget);
      expect(find.text('Completed Feature'), findsOneWidget);

      // Upcoming task must NOT appear in OutdatedTab
      expect(find.text('Future Feature'), findsNothing);

      // Filter pills
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Outdated'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
    });

    testWidgets('tapping filter pill toggles section visibility', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: OutdatedTab(
              repo: fakeRepo,
              filterCriteria: filterCriteria,
            ),
          ),
        ),
      );

      final overdueTask = Task(
        id: 'task_overdue',
        title: 'Overdue Bugfix',
        dueDate: '2020-01-01',
        status: 'todo',
      );
      final finishedTask = Task(
        id: 'task_finished',
        title: 'Completed Feature',
        dueDate: '2026-10-20',
        status: 'done',
      );

      fakeRepo.emit([overdueTask, finishedTask]);
      await tester.pumpAndSettle();

      // Tap 'Outdated' pill
      await tester.tap(find.text('Outdated'));
      await tester.pumpAndSettle();

      expect(find.text('Overdue Bugfix'), findsOneWidget);
      expect(find.text('Completed Feature'), findsNothing);

      // Tap 'Finished' pill
      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();

      expect(find.text('Overdue Bugfix'), findsNothing);
      expect(find.text('Completed Feature'), findsOneWidget);
    });
  });
}
