import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/desktop/screens/projects_tasks_screen.dart';
import 'package:intl/intl.dart';

class _FakeDesktopTaskRepo extends TaskRepository {
  final StreamController<List<Task>> _controller = StreamController<List<Task>>.broadcast();
  List<Task> _tasks = [];

  void emit(List<Task> tasks) {
    _tasks = List.from(tasks);
    _controller.add(_tasks);
  }

  @override
  Stream<List<Task>> watchTasks() => _controller.stream;

  @override
  Future<void> toggleTaskStatus(Task task, bool isDone) async {
    final updated = task.copyWith(status: isDone ? 'done' : 'todo');
    _tasks = _tasks.map((t) => t.id == task.id ? updated : t).toList();
    _controller.add(_tasks);
  }

  void dispose() => _controller.close();
}

void main() {
  group('Desktop Projects & Tasks Screen Finished vs Overdue Tests', () {
    late _FakeDesktopTaskRepo fakeRepo;

    setUp(() {
      fakeRepo = _FakeDesktopTaskRepo();
    });

    tearDown(() {
      fakeRepo.dispose();
    });

    Widget buildTestScreen() {
      return MaterialApp(
        theme: AxisTheme.dark,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: ProjectsTasksScreen(
              onNavigateToTab: (_) {},
              taskRepo: fakeRepo,
            ),
          ),
        ),
      );
    }

    testWidgets('Completed tasks with past due dates are bucketed in FINISHED, not OVERDUE',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final activeOverdue = Task(
        id: 'task_overdue',
        title: 'Active Overdue Bug Fix',
        dueDate: yesterdayStr,
        status: 'todo',
        priority: 1,
      );

      final finishedPastDue = Task(
        id: 'task_finished_past',
        title: 'Completed Architecture Spec',
        dueDate: yesterdayStr,
        status: 'done',
        priority: 2,
      );

      final todayActive = Task(
        id: 'task_today',
        title: 'Write Morning Standup Notes',
        dueDate: todayStr,
        status: 'todo',
        priority: 3,
      );

      await tester.pumpWidget(buildTestScreen());
      fakeRepo.emit([activeOverdue, finishedPastDue, todayActive]);
      await tester.pumpAndSettle();

      // Verify section headers
      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      // 'FINISHED' appears in section header and on the finished task badge pill
      expect(find.text('FINISHED'), findsWidgets);

      // Verify the finished task item displays 'Finished' and NOT 'Overdue'
      expect(find.text('Completed Architecture Spec'), findsWidgets);
      expect(find.text('Finished • $yesterdayStr'), findsOneWidget);

      // Verify the active overdue task displays 'Overdue'
      expect(find.text('Active Overdue Bug Fix'), findsWidgets);
      expect(find.text('Overdue • $yesterdayStr'), findsOneWidget);
    });

    testWidgets('Done filter tab shows all completed tasks under FINISHED with no OVERDUE section',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final pastStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 5)));

      final finishedTask = Task(
        id: 't_done_past',
        title: 'Finished Long Ago Task',
        dueDate: pastStr,
        status: 'done',
      );

      await tester.pumpWidget(buildTestScreen());
      fakeRepo.emit([finishedTask]);
      await tester.pumpAndSettle();

      // Tap on 'Done' filter tab
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Should display FINISHED section and inspector
      expect(find.text('FINISHED'), findsWidgets);
      expect(find.text('Finished Long Ago Task'), findsWidgets);

      // OVERDUE section must NOT exist
      expect(find.text('OVERDUE'), findsNothing);
    });
  });
}

