import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayers/prayer_model.dart';
import 'package:axis/data/prayers/prayer_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/calendar_scheduler.dart';
import 'package:axis/ui/desktop/screens/calendar/desktop_calendar_screen.dart';
import 'package:axis/ui/desktop/screens/command_deck/desktop_task_preview_dialog.dart';
import 'package:axis/ui/desktop/shell/desktop_sidebar.dart';
import 'package:axis/ui/tasks/services/task_form_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

      // Drag P3 task to an early empty morning slot (07:45) -> P3 placed at 07:45 without changing t1 or t2!
      final reordered = CalendarScheduler.reorderTaskWithinSameDay(
        dateStr: '2026-11-09',
        currentDayTasks: dayTasks,
        movedTaskId: 't3',
        targetDropMinute: 7 * 60 + 45,
        habitBlocks: habitBlocks,
      );

      expect(reordered.map((t) => t.id).toList(), ['t3', 't1', 't2']);
      expect(reordered[0].dueTime, '07:45'); // t3 now first (07:45 - 08:00)
      expect(reordered[1].dueTime, '08:00'); // t1 unchanged
      expect(reordered[2].dueTime, '08:30'); // t2 unchanged
    });

    test('reorderTaskWithinSameDay: if a task is from 10 to 10:25 and user moves a task to 10:20, move it to 10:26 without reordering other tasks', () {
      final dayTasks = [
        Task(id: 't_morning', title: 'Morning Task', priority: 2, dueDate: '2026-11-09', dueTime: '08:00', estimateMin: 15),
        Task(id: 't_existing', title: 'Existing Task', priority: 1, dueDate: '2026-11-09', dueTime: '10:00', estimateMin: 25), // 10:00 - 10:25
        Task(id: 't_moved', title: 'Moved Task', priority: 3, dueDate: '2026-11-09', dueTime: '14:00', estimateMin: 15),
      ];

      final reordered = CalendarScheduler.reorderTaskWithinSameDay(
        dateStr: '2026-11-09',
        currentDayTasks: dayTasks,
        movedTaskId: 't_moved',
        targetDropMinute: 10 * 60 + 20, // 10:20
        habitBlocks: const [],
      );

      // t_morning remains at 08:00 (P2 not reordered)
      final morning = reordered.firstWhere((t) => t.id == 't_morning');
      expect(morning.dueTime, '08:00');

      // t_existing remains at 10:00 (10:00 - 10:25)
      final existing = reordered.firstWhere((t) => t.id == 't_existing');
      expect(existing.dueTime, '10:00');

      // t_moved moved to first empty time: 10:26
      final moved = reordered.firstWhere((t) => t.id == 't_moved');
      expect(moved.dueTime, '10:26');
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

    test('defaultTodayTaskStartMinute calculates 30min after current time snapped to 15min grid', () {
      // 15:00 -> 15:30
      final at1500 = DateTime(2026, 11, 15, 15, 0);
      expect(CalendarScheduler.defaultTodayTaskStartMinute(at1500), 15 * 60 + 30);
      expect(CalendarScheduler.defaultTodayTaskTimeString(at1500), '15:30');

      // 15:05 -> 15:35 snapped to 15:45
      final at1505 = DateTime(2026, 11, 15, 15, 5);
      expect(CalendarScheduler.defaultTodayTaskStartMinute(at1505), 15 * 60 + 45);
      expect(CalendarScheduler.defaultTodayTaskTimeString(at1505), '15:45');

      // 05:00 (early morning before 08:00) -> defaults to 08:00
      final at0500 = DateTime(2026, 11, 15, 5, 0);
      expect(CalendarScheduler.defaultTodayTaskStartMinute(at0500), 8 * 60);
      expect(CalendarScheduler.defaultTodayTaskTimeString(at0500), '08:00');
    });

    test('reorderTaskWithinSameDay moves task to a specific later time of day without resetting to morning', () {
      final tasks = [
        Task(id: 't1', title: 'Task 1', priority: 1, dueDate: '2026-11-15', dueTime: '08:00', estimateMin: 15),
        Task(id: 't2', title: 'Task 2', priority: 2, dueDate: '2026-11-15', dueTime: '08:15', estimateMin: 15),
      ];

      // Move t1 to 15:30 (3:30 PM)
      final reordered = CalendarScheduler.reorderTaskWithinSameDay(
        dateStr: '2026-11-15',
        currentDayTasks: tasks,
        movedTaskId: 't1',
        targetDropMinute: 15 * 60 + 30,
        habitBlocks: const [],
      );

      final t1 = reordered.firstWhere((t) => t.id == 't1');
      final t2 = reordered.firstWhere((t) => t.id == 't2');
      expect(t1.dueTime, '15:30');
      expect(t2.dueTime, '08:15');
    });

    test('scheduleNewTaskForDay: if P1 task created without due time and P1 exists, move new task after existing', () {
      final existing = [
        Task(id: 't_p1_exist', title: 'P1 Exist', priority: 1, dueDate: '2026-11-16', dueTime: '08:00', estimateMin: 15),
      ];
      final newTask = Task(id: 't_p1_new', title: 'P1 New', priority: 1, dueDate: '2026-11-16', estimateMin: 15);

      final scheduled = CalendarScheduler.scheduleNewTaskForDay(
        dateStr: '2026-11-16',
        existingDayTasks: existing,
        newTask: newTask,
        habitBlocks: const [],
        dayStartMin: 8 * 60,
      );

      final existTask = scheduled.firstWhere((t) => t.id == 't_p1_exist');
      final newT = scheduled.firstWhere((t) => t.id == 't_p1_new');
      expect(existTask.dueTime, '08:00');
      expect(newT.dueTime, '08:15');
    });

    test('scheduleNewTaskForDay: if P2 task at 8:00 and user makes P1 at 8:00, move P2 down after P1', () {
      final existing = [
        Task(id: 't_p2_exist', title: 'P2 Exist', priority: 2, dueDate: '2026-11-16', dueTime: '08:00', estimateMin: 15),
      ];
      final newTask = Task(id: 't_p1_new', title: 'P1 New', priority: 1, dueDate: '2026-11-16', dueTime: '08:00', estimateMin: 15);

      final scheduled = CalendarScheduler.scheduleNewTaskForDay(
        dateStr: '2026-11-16',
        existingDayTasks: existing,
        newTask: newTask,
        habitBlocks: const [],
        dayStartMin: 8 * 60,
      );

      final p1 = scheduled.firstWhere((t) => t.id == 't_p1_new');
      final p2 = scheduled.firstWhere((t) => t.id == 't_p2_exist');
      expect(p1.dueTime, '08:00');
      expect(p2.dueTime, '08:15');
    });

    test('scheduleNewTaskForDay: if P2 task at 9:00 and user makes P1 at 10:00, do not reorder P2 after P1', () {
      final existing = [
        Task(id: 't_p2_9', title: 'P2 at 9', priority: 2, dueDate: '2026-11-16', dueTime: '09:00', estimateMin: 15),
      ];
      final newTask = Task(id: 't_p1_10', title: 'P1 at 10', priority: 1, dueDate: '2026-11-16', dueTime: '10:00', estimateMin: 15);

      final scheduled = CalendarScheduler.scheduleNewTaskForDay(
        dateStr: '2026-11-16',
        existingDayTasks: existing,
        newTask: newTask,
        habitBlocks: const [],
        dayStartMin: 8 * 60,
      );

      final p2 = scheduled.firstWhere((t) => t.id == 't_p2_9');
      final p1 = scheduled.firstWhere((t) => t.id == 't_p1_10');
      expect(p2.dueTime, '09:00');
      expect(p1.dueTime, '10:00');
    });

    test('collision resolution: moving P1 to 9:00 with existing P2 at 9:00 moves P2 forward to next space, never to empty space before', () {
      final dayTasks = [
        // 08:00 - 09:00 is empty space before 9:00
        Task(id: 't_p2_9', title: 'P2 at 9:00', priority: 2, dueDate: '2026-11-16', dueTime: '09:00', estimateMin: 30),
        Task(id: 't_p1_later', title: 'P1 later', priority: 1, dueDate: '2026-11-16', dueTime: '14:00', estimateMin: 30),
      ];

      final reordered = CalendarScheduler.reorderTaskWithinSameDay(
        dateStr: '2026-11-16',
        currentDayTasks: dayTasks,
        movedTaskId: 't_p1_later',
        targetDropMinute: 9 * 60, // 09:00
        habitBlocks: const [],
      );

      final p1 = reordered.firstWhere((t) => t.id == 't_p1_later');
      final p2 = reordered.firstWhere((t) => t.id == 't_p2_9');
      // P1 takes 09:00
      expect(p1.dueTime, '09:00');
      // P2 moves forward to the next space (after P1: 09:30 + 1 = 09:31), NEVER to 08:00
      expect(p2.dueTime, '09:31');
    });

    test('collision resolution: if priorities are equal at 9:00, first task stays and incoming moves to next space forward', () {
      final dayTasks = [
        // 08:00 - 09:00 is empty space
        Task(id: 't_p1_first', title: 'P1 First', priority: 1, dueDate: '2026-11-16', dueTime: '09:00', estimateMin: 30),
        Task(id: 't_p1_second', title: 'P1 Second', priority: 1, dueDate: '2026-11-16', dueTime: '15:00', estimateMin: 30),
      ];

      final reordered = CalendarScheduler.reorderTaskWithinSameDay(
        dateStr: '2026-11-16',
        currentDayTasks: dayTasks,
        movedTaskId: 't_p1_second',
        targetDropMinute: 9 * 60, // 09:00
        habitBlocks: const [],
      );

      final first = reordered.firstWhere((t) => t.id == 't_p1_first');
      final second = reordered.firstWhere((t) => t.id == 't_p1_second');
      // First task stays at 09:00
      expect(first.dueTime, '09:00');
      // Second task moves forward to next space (09:31), never backward into 08:00
      expect(second.dueTime, '09:31');
    });

    test('collision resolution: cascading collision reorders multiple tasks forward by priority', () {
      final dayTasks = [
        Task(id: 't_p2_9', title: 'P2 at 09:00', priority: 2, dueDate: '2026-11-16', dueTime: '09:00', estimateMin: 30),
        Task(id: 't_p3_930', title: 'P3 at 09:30', priority: 3, dueDate: '2026-11-16', dueTime: '09:31', estimateMin: 30),
        Task(id: 't_p1_move', title: 'P1 move to 09:00', priority: 1, dueDate: '2026-11-16', dueTime: '16:00', estimateMin: 30),
      ];

      final reordered = CalendarScheduler.reorderTaskWithinSameDay(
        dateStr: '2026-11-16',
        currentDayTasks: dayTasks,
        movedTaskId: 't_p1_move',
        targetDropMinute: 9 * 60,
        habitBlocks: const [],
      );

      final p1 = reordered.firstWhere((t) => t.id == 't_p1_move');
      final p2 = reordered.firstWhere((t) => t.id == 't_p2_9');
      final p3 = reordered.firstWhere((t) => t.id == 't_p3_930');

      // P1 wins 09:00
      expect(p1.dueTime, '09:00');
      // P2 displaces P3 at 09:31 because P2 (rank 2) has higher priority than P3 (rank 3)
      expect(p2.dueTime, '09:31');
      // P3 is pushed forward after P2 to 10:02
      expect(p3.dueTime, '10:02');
    });
  });

  group('TaskFormService calendar auto-scheduling tests', () {
    test('if task is P1 and user changed time to 9:30 and there is P2 at 8:00, do not reorder them', () async {
      const todayStr = '2026-11-16';
      final p1Task = Task(id: 'task_p1', title: 'P1 Task', priority: 1, dueDate: todayStr, dueTime: '08:00', estimateMin: 15);
      final p2Task = Task(id: 'task_p2', title: 'P2 Task', priority: 2, dueDate: todayStr, dueTime: '08:00', estimateMin: 15);
      final fakeTasks = _FakeTaskRepository([p1Task, p2Task]);

      final service = TaskFormService(
        projectRepo: _FakeProjectRepository(),
        tagRepo: _FakeTagRepository(),
        taskRepo: fakeTasks,
        habitRepo: _FakeHabitRepository(),
        prayerRepo: _FakePrayerRepository(),
        isInitialized: () => true,
      );

      // User changes P1 time to 9:30
      await service.saveTask(
        taskToEdit: p1Task,
        title: 'P1 Task',
        notes: '',
        priority: 1,
        rawProject: null,
        selectedTags: const {},
        additionalTag: '',
        selectedDate: DateTime(2026, 11, 16),
        dueTime: '09:30',
        estimateMin: 15,
        existingProjects: const [],
      );

      final updatedP1 = fakeTasks.store.firstWhere((t) => t.id == 'task_p1');
      final currentP2 = fakeTasks.store.firstWhere((t) => t.id == 'task_p2');
      expect(updatedP1.dueTime, '09:30');
      expect(currentP2.dueTime, '08:00'); // P2 is not reordered!
    });
    test('new task for today is scheduled after now time (e.g. 15:00 -> 15:30)', () async {
      final refTime = DateTime(2026, 11, 15, 15, 0);
      final todayStr = CalendarScheduler.formatDate(refTime);
      final fakeTasks = _FakeTaskRepository();

      final service = TaskFormService(
        projectRepo: _FakeProjectRepository(),
        tagRepo: _FakeTagRepository(),
        taskRepo: fakeTasks,
        habitRepo: _FakeHabitRepository(),
        prayerRepo: _FakePrayerRepository(),
        isInitialized: () => true,
      );

      final created = await service.saveTask(
        title: 'Task Created at 3 PM',
        notes: '',
        priority: 1,
        rawProject: null,
        selectedTags: const {},
        additionalTag: '',
        selectedDate: refTime,
        estimateMin: 15,
        existingProjects: const [],
        referenceTime: refTime,
      );

      expect(created.dueDate, todayStr);
      expect(created.dueTime, '15:30');
    });
    test('defaults estimateMin to 15 when null, and packs P1->P2->P3 around daily habits for today', () async {
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
        selectedDate: DateTime.now(),
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

    test('creating task with selectedDate: null creates task without dueDate or dueTime, not scheduled on calendar', () async {
      final fakeTasks = _FakeTaskRepository([
        Task(
          id: 't_calendar',
          title: 'Scheduled Task',
          priority: 1,
          dueDate: '2026-11-16',
          dueTime: '09:00',
          estimateMin: 15,
        ),
      ]);

      final service = TaskFormService(
        projectRepo: _FakeProjectRepository(),
        tagRepo: _FakeTagRepository(),
        taskRepo: fakeTasks,
        habitRepo: _FakeHabitRepository(),
        prayerRepo: _FakePrayerRepository(),
        isInitialized: () => true,
      );

      final created = await service.saveTask(
        title: 'Undated Backlog Task',
        notes: '',
        priority: 2,
        rawProject: null,
        selectedTags: const {},
        additionalTag: '',
        selectedDate: null,
        estimateMin: 15,
        existingProjects: const [],
      );

      expect(created.dueDate, isNull);
      expect(created.dueTime, isNull);

      final saved = fakeTasks.store.firstWhere((t) => t.id == created.id);
      expect(saved.dueDate, isNull);
      expect(saved.dueTime, isNull);

      // Existing task was not touched:
      final scheduled = fakeTasks.store.firstWhere((t) => t.id == 't_calendar');
      expect(scheduled.dueTime, '09:00');
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

      // Same-day drag: drag P3 onto P1 -> P1 is NOT reordered and keeps 08:00; P3 moves to first empty time (08:16)
      final p1Center = tester.getCenter(find.byKey(const ValueKey('calendar_task_t_p1')));
      final p3Center = tester.getCenter(find.byKey(const ValueKey('calendar_task_t_p3')));
      await tester.dragFrom(p3Center, p1Center - p3Center);
      await tester.pumpAndSettle();

      expect(fakeRepo.store.firstWhere((t) => t.id == 't_p1').dueTime, '08:00');
      expect(fakeRepo.store.firstWhere((t) => t.id == 't_p3').dueTime, '08:16');
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('calendar_task_t_p1'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('calendar_task_t_p3'))).dy),
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

      // Resize t_p1 down by +96px (+30 min at 30m scale -> 45 min total), pushing t_tue_p2 to 08:45
      await tester.drag(
        find.byKey(const ValueKey('calendar_task_resize_t_p1')),
        const Offset(0, 96),
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

      // Default: 30 Min (half hour scale)
      expect(find.text('30 Min'), findsOneWidget);
      // Gutter shows half-hour markings by default
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

      // Zoom out to 1 Hour
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

    testWidgets('default week starts on Sunday and columns show Sun as first column', (tester) async {
      tester.view.physicalSize = const Size(1024, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 2026-11-11 is a Wednesday
      final wednesday = DateTime(2026, 11, 11);

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              initialTasks: const [],
              initialHabits: const [],
              initialSelectedDate: wednesday,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Week should start on Sunday 2026-11-08
      expect(find.byKey(const ValueKey('calendar_day_header_2026-11-08')), findsOneWidget);
      // Header text for Sunday should be visible
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('DesktopTaskPreviewDialog renders Move Time button', (tester) async {
      final task = Task(
        id: 't_preview',
        title: 'Task to move',
        priority: 1,
        dueDate: '2026-11-15',
        dueTime: '08:00',
        estimateMin: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(
            body: DesktopTaskPreviewDialog(
              initialTask: task,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Move Time'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_rounded), findsWidgets);
    });

    testWidgets('if a task is deleted, remaining tasks are not reordered and keep their due time', (tester) async {
      const dateStr = '2026-11-16';
      final tasks = [
        Task(id: 't_del', title: 'Task to Delete', priority: 1, dueDate: dateStr, dueTime: '08:00', estimateMin: 15),
        Task(id: 't_keep', title: 'Task to Keep', priority: 2, dueDate: dateStr, dueTime: '09:00', estimateMin: 15),
      ];

      final fakeTasks = _FakeTaskRepository(tasks);
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              taskRepo: fakeTasks,
              initialTasks: tasks,
              initialSelectedDate: DateTime(2026, 11, 16),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Task to Keep'), findsOneWidget);
      final beforeY = tester.getTopLeft(find.byKey(const ValueKey('calendar_task_t_keep'))).dy;

      // Simulate deleting t_del
      tasks.removeWhere((t) => t.id == 't_del');
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              taskRepo: fakeTasks,
              initialTasks: tasks,
              initialSelectedDate: DateTime(2026, 11, 16),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Task to Keep stayed at 09:00 (did not collapse to 08:00)
      expect(find.text('Task to Keep'), findsOneWidget);
      final afterY = tester.getTopLeft(find.byKey(const ValueKey('calendar_task_t_keep'))).dy;
      expect(afterY, equals(beforeY));
    });

    testWidgets('checking prayer/habit today checks only today and yesterday checked prayer stays checked', (tester) async {
      const sunday = '2026-11-15';
      const mondayToday = '2026-11-16';
      const tuesday = '2026-11-17';

      // Suppose yesterday (Sunday), Fajr was checked in habit_logs.
      // Today (Monday), user checks Dhuhr.
      final completedLogs = {
        sunday: {'fajr', 'h_daily'},
        mondayToday: {'dhuhr'},
      };

      final habits = [
        Habit(id: 'h_daily', name: 'Morning Focus', scheduleType: 'daily', remindTime: '08:00', isEnabled: true),
      ];
      final defaultP = PrayerRepository.defaultPrayers('u1');
      final prayers = [
        defaultP.firstWhere((p) => p.prayerCode == 'fajr').copyWith(isDone: false),
        defaultP.firstWhere((p) => p.prayerCode == 'dhuhr').copyWith(isDone: true),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              initialHabits: habits,
              initialPrayers: prayers,
              initialCompletedLogs: completedLogs,
              initialSelectedDate: DateTime(2026, 11, 16),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On Sunday (yesterday):
      // Fajr was checked yesterday -> Fajr has check icon!
      // Dhuhr was NOT checked yesterday -> Dhuhr is not checked on Sunday!
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_prayer_${sunday}_fajr')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_prayer_${sunday}_dhuhr')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
      // Habit was checked yesterday on Sunday -> check icon!
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_habit_${sunday}_h_daily')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );

      // On Monday (today):
      // Dhuhr was checked today -> Dhuhr has check icon on Monday!
      // Fajr was NOT checked today -> Fajr is NOT checked on Monday!
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_prayer_${mondayToday}_dhuhr')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_prayer_${mondayToday}_fajr')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
      // Habit is not checked today on Monday -> lock icon, not check!
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_habit_${mondayToday}_h_daily')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );

      // On Tuesday (tomorrow):
      // Neither Fajr nor Dhuhr nor habit is checked!
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_prayer_${tuesday}_fajr')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_prayer_${tuesday}_dhuhr')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar_habit_${tuesday}_h_daily')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('tasks without due date/time do not appear on any day in the calendar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final undatedTask = Task(
        id: 't_undated',
        title: 'Undated Floating Task',
        priority: 1,
        dueDate: null,
        dueTime: null,
      );
      final datedTask = Task(
        id: 't_dated',
        title: 'Dated Scheduled Task',
        priority: 1,
        dueDate: '2026-11-16',
        dueTime: '10:00',
        estimateMin: 15,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DesktopCalendarScreen(
              initialTasks: [undatedTask, datedTask],
              initialHabits: const [],
              initialPrayers: const [],
              initialSelectedDate: DateTime(2026, 11, 16),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('calendar_task_t_dated')), findsOneWidget);
      expect(find.byKey(const ValueKey('calendar_task_t_undated')), findsNothing);
      expect(find.text('Undated Floating Task'), findsNothing);
    });
  });
}
