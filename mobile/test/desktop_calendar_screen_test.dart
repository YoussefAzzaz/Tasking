import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayers/prayer_model.dart';
import 'package:axis/data/prayers/prayer_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/calendar_scheduler.dart';
import 'package:axis/ui/desktop/screens/calendar/desktop_calendar_screen.dart';
import 'package:axis/ui/desktop/shell/desktop_sidebar.dart';
import 'package:axis/ui/tasks/services/task_form_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTaskRepository extends TaskRepository {
  final List<Task> store;

  _FakeTaskRepository([List<Task>? initial]) : store = [...?initial];

  @override
  Future<List<Task>> getTasks({int? limit, int? offset}) async =>
      List<Task>.from(store);

  @override
  Stream<List<Task>> watchTasks({
    int? limit,
    int? offset,
    bool forceRefresh = false,
  }) =>
      Stream.value(List<Task>.from(store));

  @override
  Future<void> addTask(Task task) async {
    store.add(task);
  }

  @override
  Future<void> updateTask(Task task) async {
    final idx = store.indexWhere((t) => t.id == task.id);
    if (idx >= 0) {
      store[idx] = task;
    } else {
      store.add(task);
    }
  }
}

class _FakeHabitRepository extends HabitRepository {
  final List<Habit> store;

  _FakeHabitRepository([List<Habit>? initial]) : store = [...?initial];

  @override
  Stream<List<Habit>> watchHabits({int? limit, int? offset}) =>
      Stream.value(List<Habit>.from(store));
}

class _FakePrayerRepository extends PrayerRepository {
  final List<Prayer> store;

  _FakePrayerRepository([List<Prayer>? initial])
      : store = [...(initial ?? PrayerRepository.defaultPrayers())];

  @override
  Stream<List<Prayer>> watchPrayers([String? userId]) =>
      Stream.value(List<Prayer>.from(store));
}

class _FakeProjectRepository extends ProjectRepository {
  @override
  Future<void> addProject(Project project) async {}
}

class _FakeTagRepository implements TagRepository {
  @override
  Future<void> addTag(String tagName) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CalendarScheduler unit tests', () {
    test('buildDailyHabitBlocks keeps only enabled daily habits & excludes weekly and legacy prayers', () {
      final habits = [
        Habit(
          id: 'h_daily',
          name: 'Morning Reading',
          scheduleType: 'daily',
          remindTime: '08:00',
          isEnabled: true,
        ),
        Habit(
          id: 'h_weekly',
          name: 'Weekly Review',
          scheduleType: 'weekly',
          remindTime: '10:00',
          isEnabled: true,
        ),
        Habit(
          id: 'h_disabled',
          name: 'Disabled Daily',
          scheduleType: 'daily',
          remindTime: '09:00',
          isEnabled: false,
        ),
        Habit(
          id: 'fajr',
          name: 'Fajr Prayer',
          scheduleType: 'daily',
          remindTime: '05:30',
          isEnabled: true,
        ),
      ];

      final blocks = CalendarScheduler.buildDailyHabitBlocks(habits);

      expect(blocks.length, 1);
      expect(blocks.first.habit.id, 'h_daily');
      expect(blocks.first.startMinute, 8 * 60);
      expect(blocks.first.endMinute, 8 * 60 + 15);
      expect(blocks.first.durationMin, 15);
    });

    test('buildDailyPrayerBlocks creates fixed 15-minute prayer slots and avoids overlapping tasks', () {
      final defaultPrayers = PrayerRepository.defaultPrayers();
      final prayerBlocks = CalendarScheduler.buildDailyPrayerBlocks(defaultPrayers);

      expect(prayerBlocks.length, 5);
      for (final pb in prayerBlocks) {
        expect(pb.durationMin, 15);
        expect(pb.endMinute, pb.startMinute + 15);
      }

      final dhuhrBlock = prayerBlocks.firstWhere((p) => p.prayer.prayerCode == 'dhuhr');
      expect(dhuhrBlock.startMinute, 12 * 60 + 45); // 12:45
      expect(dhuhrBlock.endMinute, 13 * 60); // 13:00

      final tasks = [
        Task(id: 't_noon', title: 'Noon Task', priority: 1, dueDate: '2026-11-09', estimateMin: 30),
      ];
      final packed = CalendarScheduler.sortAndPackDayByPriority(
        dateStr: '2026-11-09',
        dayTasks: tasks,
        habitBlocks: const [],
        prayerBlocks: prayerBlocks,
        dayStartMin: 12 * 60 + 30, // 12:30
      );
      // At 12:30, a 30m task would run 12:30-13:00 which collides with Dhuhr (12:45-13:00).
      // So it must jump past Dhuhr and start at 13:00!
      expect(packed.first.dueTime, '13:00');
    });

    test('sortAndPackDayByPriority sorts P1 -> P2 -> P3 morning to night and skips daily habit slots', () {
      final habitBlocks = CalendarScheduler.buildDailyHabitBlocks([
        Habit(
          id: 'h_morning',
          name: 'Deep Breath',
          scheduleType: 'daily',
          remindTime: '08:15',
          isEnabled: true,
        ),
      ]); // 08:15 - 08:30 (15 min habit)

      final tasks = [
        Task(id: 't3', title: 'P3 Task', priority: 3, dueDate: '2026-11-09', estimateMin: 15),
        Task(id: 't1', title: 'P1 Task', priority: 1, dueDate: '2026-11-09', estimateMin: 15),
        Task(id: 't2', title: 'P2 Task', priority: 2, dueDate: '2026-11-09', estimateMin: 30),
        Task(id: 'tdone', title: 'Done Task', status: 'done', priority: 1, dueDate: '2026-11-09', estimateMin: 15),
      ];

      final packed = CalendarScheduler.sortAndPackDayByPriority(
        dateStr: '2026-11-09',
        dayTasks: tasks,
        habitBlocks: habitBlocks,
      );

      expect(packed.map((t) => t.id).toList(), ['t1', 't2', 't3']);
      // t1 takes 08:00 - 08:15; then daily habit occupies 08:15 - 08:30;
      // so t2 jumps past 08:30 and starts at 08:30 - 09:00; t3 starts at 09:00.
      expect(packed[0].dueTime, '08:00');
      expect(packed[1].dueTime, '08:30');
      expect(packed[2].dueTime, '09:00');
    });

    test('reorderTaskWithinSameDay moves task to target slot without priority re-sorting and still avoids habits', () {
      final habitBlocks = CalendarScheduler.buildDailyHabitBlocks([
        Habit(
          id: 'h_morning',
          name: 'Morning Walk',
          scheduleType: 'daily',
          remindTime: '08:15',
          isEnabled: true,
        ),
      ]); // 08:15 - 08:30

      final dayTasks = [
        Task(id: 't1', title: 'P1 Task', priority: 1, dueDate: '2026-11-09', dueTime: '08:00', estimateMin: 15),
        Task(id: 't2', title: 'P2 Task', priority: 2, dueDate: '2026-11-09', dueTime: '08:30', estimateMin: 15),
        Task(id: 't3', title: 'P3 Task', priority: 3, dueDate: '2026-11-09', dueTime: '08:45', estimateMin: 15),
      ];

      // Drag P3 task up to morning (08:05) -> P3 becomes first without re-sorting!
      final reordered = CalendarScheduler.reorderTaskWithinSameDay(
        dateStr: '2026-11-09',
        currentDayTasks: dayTasks,
        movedTaskId: 't3',
        targetDropMinute: 8 * 60 + 5,
        habitBlocks: habitBlocks,
      );

      expect(reordered.map((t) => t.id).toList(), ['t3', 't1', 't2']);
      expect(reordered[0].dueTime, '08:00'); // t3 now first (08:00 - 08:15)
      expect(reordered[1].dueTime, '08:30'); // t1 skips 08:15-08:30 habit block
      expect(reordered[2].dueTime, '08:45');
    });

    test('moveTaskToDay and resizeTaskDuration re-sort affected days by priority', () {
      final habitBlocks = <CalendarHabitBlock>[];
      final allTasks = [
        Task(id: 't_mon_p1', title: 'Mon P1', priority: 1, dueDate: '2026-11-09', dueTime: '08:00', estimateMin: 15),
        Task(id: 't_tue_p2', title: 'Tue P2', priority: 2, dueDate: '2026-11-10', dueTime: '08:00', estimateMin: 15),
      ];

      // Move Mon P1 to Tuesday -> Tue automatically sorts P1 -> P2
      final moved = CalendarScheduler.moveTaskToDay(
        allTasks: allTasks,
        movedTaskId: 't_mon_p1',
        targetDateStr: '2026-11-10',
        habitBlocks: habitBlocks,
      );

      final tueTasks = moved.where((t) => t.dueDate == '2026-11-10').toList();
      expect(tueTasks.map((t) => t.id).toList(), ['t_mon_p1', 't_tue_p2']);
      expect(tueTasks[0].dueTime, '08:00');
      expect(tueTasks[1].dueTime, '08:15');

      // Resize t_mon_p1 on Tuesday to 45 min -> automatically resorts & repacks Tuesday
      final resized = CalendarScheduler.resizeTaskDuration(
        dateStr: '2026-11-10',
        dayTasks: tueTasks,
        resizedTaskId: 't_mon_p1',
        newEstimateMin: 45,
        habitBlocks: habitBlocks,
      );

      expect(resized.map((t) => t.id).toList(), ['t_mon_p1', 't_tue_p2']);
      expect(resized[0].estimateMin, 45);
      expect(resized[0].dueTime, '08:00');
      expect(resized[1].dueTime, '08:45');
    });

    test('buildWeekDays starts week on chosen startWeekday across year/month changes', () {
      final daysSunStart = CalendarScheduler.buildWeekDays(
        DateTime(2027, 2, 2), // Tuesday
        DateTime.sunday,
      );
      expect(daysSunStart.length, 7);
      expect(daysSunStart.first, DateTime(2027, 1, 31));
      expect(daysSunStart.first.weekday, DateTime.sunday);
      expect(daysSunStart.last, DateTime(2027, 2, 6));
    });
  });

  group('TaskFormService calendar auto-scheduling tests', () {
    test('defaults estimateMin to 15 and selectedDate to today, and packs P1->P2->P3 around daily habits', () async {
      final todayStr = CalendarScheduler.formatDate(DateTime.now());
      final fakeTasks = _FakeTaskRepository([
        Task(
          id: 'existing_p1',
          title: 'Urgent P1',
          priority: 1,
          dueDate: todayStr,
          estimateMin: 15,
        ),
      ]);
      final fakeHabits = _FakeHabitRepository([
        Habit(
          id: 'daily_focus',
          name: 'Daily Breath',
          scheduleType: 'daily',
          remindTime: '08:15',
          isEnabled: true,
        ),
      ]);

      final service = TaskFormService(
        projectRepo: _FakeProjectRepository(),
        tagRepo: _FakeTagRepository(),
        taskRepo: fakeTasks,
        habitRepo: fakeHabits,
        prayerRepo: _FakePrayerRepository(),
        isInitialized: () => true,
      );

      final created = await service.saveTask(
        title: 'New Medium Task',
        notes: '',
        priority: 2,
        rawProject: null,
        selectedTags: const {},
        additionalTag: '',
        selectedDate: null,
        estimateMin: null,
        existingProjects: const [],
      );

      expect(created.estimateMin, 15);
      expect(created.dueDate, todayStr);

      final scheduledP1 =
          fakeTasks.store.firstWhere((t) => t.id == 'existing_p1');
      final scheduledNew = fakeTasks.store.firstWhere((t) => t.id == created.id);
      expect(scheduledP1.dueTime, '08:00');
      // Skips 08:15-08:30 daily habit slot:
      expect(scheduledNew.dueTime, '08:30');
    });
  });

  group('DesktopCalendarScreen widget tests', () {
    testWidgets('renders 7 columns, 24h grid, daily habits, excludes weekly habits, and avoids 1024x700 overflow', (tester) async {
      tester.view.physicalSize = const Size(1024, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final monday = DateTime(2026, 11, 9);
      final tasks = [
        Task(id: 't_p3', title: 'Low Task', priority: 3, dueDate: '2026-11-09', estimateMin: 15),
        Task(id: 't_p1', title: 'High Task', priority: 1, dueDate: '2026-11-09', estimateMin: 15),
      ];
      final habits = [
        Habit(id: 'h_daily', name: 'Read Quran', scheduleType: 'daily', remindTime: '08:15', isEnabled: true),
        Habit(id: 'h_weekly', name: 'Weekly Sync', scheduleType: 'weekly', remindTime: '10:00', isEnabled: true),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              initialTasks: tasks,
              initialHabits: habits,
              initialSelectedDate: monday,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('calendar_start_day_selector')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_day_selector')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_month_selector')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_year_selector')), findsOneWidget);

      // Daily habit and prayers shown, weekly habit excluded
      expect(find.byKey(const ValueKey('calendar_habit_2026-11-09_h_daily')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_prayer_2026-11-09_fajr')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_prayer_2026-11-09_dhuhr')), findsOneWidget);
      expect(find.text('Weekly Sync'), findsNothing);

      // Habits and prayers cannot be resized (no resize handle)
      expect(find.byKey(const ValueKey('calendar_habit_resize_h_daily')), findsNothing);
      expect(find.byKey(const ValueKey('calendar_prayer_resize_fajr')), findsNothing);

      // P1 should appear vertically above daily habit and P3 below daily habit
      final p1Top = tester.getTopLeft(find.byKey(const ValueKey('calendar_task_t_p1'))).dy;
      final habitTop = tester.getTopLeft(find.byKey(const ValueKey('calendar_habit_2026-11-09_h_daily'))).dy;
      final p3Top = tester.getTopLeft(find.byKey(const ValueKey('calendar_task_t_p3'))).dy;
      expect(p1Top, lessThan(habitTop));
      expect(habitTop, lessThan(p3Top));
    });

    testWidgets('start-day, year, month, and day selectors update the visible week columns', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              initialTasks: const [],
              initialHabits: const [],
              initialSelectedDate: DateTime(2026, 11, 9),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch start day to Sunday
      await tester.tap(find.byKey(const ValueKey('calendar_start_day_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sun').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('calendar_day_header_2026-11-08')), findsOneWidget);

      // Switch Year to 2027, Month to Jan, Day to 15
      await tester.tap(find.byKey(const ValueKey('calendar_year_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2027').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('calendar_month_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jan').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('calendar_day_selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('calendar_day_header_2027-01-15')), findsOneWidget);
    });

    testWidgets('same-day drag reorders task without priority resort; cross-day drag and resize trigger priority resort', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = _FakeTaskRepository([
        Task(id: 't_p1', title: 'Urgent One', priority: 1, dueDate: '2026-11-09', estimateMin: 15),
        Task(id: 't_p3', title: 'Low Three', priority: 3, dueDate: '2026-11-09', estimateMin: 15),
        Task(id: 't_tue_p2', title: 'Tue Mid', priority: 2, dueDate: '2026-11-10', estimateMin: 15),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              taskRepo: fakeRepo,
              habitRepo: _FakeHabitRepository(const []),
              initialSelectedDate: DateTime(2026, 11, 9),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Same-day drag: drag P3 up onto P1
      final p1Center = tester.getCenter(find.byKey(const ValueKey('calendar_task_t_p1')));
      final p3Center = tester.getCenter(find.byKey(const ValueKey('calendar_task_t_p3')));
      await tester.dragFrom(p3Center, p1Center - p3Center);
      await tester.pumpAndSettle();

      // P3 must stay first (no priority resort on same-day move)
      expect(fakeRepo.store.firstWhere((t) => t.id == 't_p3').dueTime, '08:00');
      expect(fakeRepo.store.firstWhere((t) => t.id == 't_p1').dueTime, '08:15');
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('calendar_task_t_p3'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('calendar_task_t_p1'))).dy),
      );

      // Cross-day drag: drag t_p1 onto Tuesday (2026-11-10)
      final p1Pos = tester.getCenter(find.byKey(const ValueKey('calendar_task_t_p1')));
      final tueCenterX = tester.getCenter(find.byKey(const ValueKey('calendar_day_header_2026-11-10'))).dx;
      await tester.dragFrom(p1Pos, Offset(tueCenterX - p1Pos.dx, 0));
      await tester.pumpAndSettle();

      // Tuesday automatically resorts: t_p1 (P1) before t_tue_p2 (P2)
      expect(fakeRepo.store.firstWhere((t) => t.id == 't_p1').dueDate, '2026-11-10');
      expect(fakeRepo.store.firstWhere((t) => t.id == 't_p1').dueTime, '08:00');
      expect(fakeRepo.store.firstWhere((t) => t.id == 't_tue_p2').dueTime, '08:15');

      // Resize t_p1 down by +48px (+30 min -> 45 min total), pushing t_tue_p2 to 08:45
      await tester.drag(
        find.byKey(const ValueKey('calendar_task_resize_t_p1')),
        const Offset(0, 48),
      );
      await tester.pumpAndSettle();

      expect(fakeRepo.store.firstWhere((t) => t.id == 't_p1').estimateMin, 45);
      expect(fakeRepo.store.firstWhere((t) => t.id == 't_p1').dueTime, '08:00');
      expect(fakeRepo.store.firstWhere((t) => t.id == 't_tue_p2').dueTime, '08:45');
    });

    testWidgets('calendar zoom feature zooms lines to 1h, 30m, and 15m resolutions', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              initialTasks: const [],
              initialHabits: const [],
              initialSelectedDate: DateTime(2026, 11, 9),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('calendar_zoom_selector')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_zoom_in_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_zoom_out_button')), findsOneWidget);

      // Default: 1 Hour (lines hour by hour)
      expect(find.text('1 Hour'), findsOneWidget);

      // Zoom in to 30 Min (lines each half hour)
      await tester.tap(find.byKey(const ValueKey('calendar_zoom_in_button')));
      await tester.pumpAndSettle();
      expect(find.text('30 Min'), findsOneWidget);
      // Gutter shows half-hour markings
      expect(find.text('08:30'), findsOneWidget);

      // Zoom in to 15 Min (lines each quarter hour)
      await tester.tap(find.byKey(const ValueKey('calendar_zoom_in_button')));
      await tester.pumpAndSettle();
      expect(find.text('15 Min'), findsOneWidget);
      // Gutter shows quarter-hour markings
      expect(find.text('08:15'), findsOneWidget);
      expect(find.text('08:45'), findsOneWidget);

      // Zoom out back to 30 Min
      await tester.tap(find.byKey(const ValueKey('calendar_zoom_out_button')));
      await tester.pumpAndSettle();
      expect(find.text('30 Min'), findsOneWidget);

      // Zoom out back to 1 Hour
      await tester.tap(find.byKey(const ValueKey('calendar_zoom_out_button')));
      await tester.pumpAndSettle();
      expect(find.text('1 Hour'), findsOneWidget);
    });

    testWidgets('DesktopSidebar exposes Calendar item at index 7', (tester) async {
      tester.view.physicalSize = const Size(1024, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopSidebar(
              selectedTab: selected,
              onSelectTab: (idx) => selected = idx,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Calendar'), findsOneWidget);
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      expect(selected, 7);
    });
  });
}
