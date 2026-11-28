import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayers/prayer_model.dart';
import 'package:axis/data/prayers/prayer_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/calendar_scheduler.dart';
import 'package:axis/domain/quick_add_parser.dart';
import 'package:axis/domain/recurrence_engine.dart';
import 'package:axis/ui/calendar/mobile_calendar_screen.dart';
import 'package:axis/ui/desktop/screens/calendar/desktop_calendar_screen.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemTaskRepository extends TaskRepository {
  final List<Task> store;
  _MemTaskRepository([List<Task>? initial]) : store = [...?initial];

  @override
  Future<List<Task>> getTasks({int? limit, int? offset}) async =>
      List<Task>.from(store);

  @override
  Stream<List<Task>> watchTasks({int? limit, int? offset}) =>
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

class _NoOpProjectRepo extends ProjectRepository {
  @override
  Future<void> addProject(Project project) async {}
}

class _NoOpTagRepo implements TagRepository {
  @override
  Future<void> addTag(String tagName) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithL10n(
  Widget child, {
  Locale locale = const Locale('en'),
  Size size = const Size(1280, 820),
}) {
  return MaterialApp(
    theme: AxisTheme.dark,
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Habit & Prayer Non-Collision Guarantees', () {
    const wedDate = '2026-12-02'; // Wednesday

    final habits = [
      Habit(
        id: 'h_morning',
        name: 'Morning Reading',
        scheduleType: 'daily',
        remindTime: '08:30',
        isEnabled: true,
      ),
      Habit(
        id: 'h_mid',
        name: 'Stretch',
        scheduleType: 'daily',
        remindTime: '09:15',
        isEnabled: true,
      ),
    ];
    final prayers = PrayerRepository.defaultPrayers();

    test('creating or scheduling a task overlapping a habit or prayer keeps its exact time', () async {
      final repo = _MemTaskRepository();
      final service = TaskFormService(
        projectRepo: _NoOpProjectRepo(),
        tagRepo: _NoOpTagRepo(),
        taskRepo: repo,
        isInitialized: () => true,
      );

      // 90-minute teaching session at 08:30 (overlaps 08:30 & 09:15 habits)
      final teaching = await service.saveTask(
        title: 'Teaching Session',
        notes: '- [ ] Take attendance',
        priority: 1,
        rawProject: 'School',
        selectedTags: const {'teaching'},
        additionalTag: '',
        selectedDate: DateTime(2026, 12, 2),
        dueTime: '08:30',
        estimateMin: 90,
        recurrenceRule: 'RRULE:FREQ=WEEKLY;BYDAY=WE',
        existingProjects: const [],
      );

      expect(teaching.dueDate, wedDate);
      expect(teaching.dueTime, '08:30');
      expect(teaching.estimateMin, 90);
      expect(teaching.recurrenceRule, 'RRULE:FREQ=WEEKLY;BYDAY=WE');
      expect(teaching.recurrenceMode, 'fixed');

      // Task overlapping Dhuhr prayer (12:45-13:00) via displaceConflicting
      repo.store.add(
        Task(
          id: 'existing_noon',
          title: 'Quick Call',
          priority: 2,
          dueDate: wedDate,
          dueTime: '12:30',
          estimateMin: 15,
        ),
      );

      final noonLecture = await service.saveTask(
        title: 'Noon Lecture',
        notes: '',
        priority: 2,
        rawProject: null,
        selectedTags: const {},
        additionalTag: '',
        selectedDate: DateTime(2026, 12, 2),
        dueTime: '12:30',
        estimateMin: 60, // 12:30 - 13:30 overlaps Dhuhr (12:45 - 13:00)
        existingProjects: const [],
        displaceConflicting: true,
      );

      // Noon Lecture MUST stay at 12:30 (not pushed to 13:00 by Dhuhr!)
      expect(noonLecture.dueTime, '12:30');
      // Displaced Quick Call moves right after Noon Lecture to 13:30
      final displaced = repo.store.firstWhere((t) => t.id == 'existing_noon');
      expect(displaced.dueTime, '13:30');
    });

    test('resolveCollisionPlacement and findNextAvailableMinute ignore habitBlocks and prayerBlocks', () {
      final habitBlocks = CalendarScheduler.buildDailyHabitBlocks(habits);
      final prayerBlocks = CalendarScheduler.buildDailyPrayerBlocks(prayers);

      // Place a 60m task at 12:30 overlapping Dhuhr (12:45 - 13:00) with no conflicting tasks
      final placed = CalendarScheduler.resolveCollisionPlacement(
        dateStr: wedDate,
        existingDayTasks: const [],
        incomingTask: Task(
          id: 't_dhuhr_overlap',
          title: 'Workshop',
          dueDate: wedDate,
          estimateMin: 60,
        ),
        targetStartMinute: 12 * 60 + 30,
        habitBlocks: habitBlocks,
        prayerBlocks: prayerBlocks,
      );
      expect(placed.single.dueTime, '12:30');

      // Next available minute after a 12:15-12:45 task must be 12:45 even though Dhuhr is at 12:45!
      final nextMin = CalendarScheduler.findNextAvailableMinute(
        dateStr: wedDate,
        searchFromMinute: 12 * 60 + 15,
        durationMin: 30,
        existingTasks: [
          Task(
            id: 't_1215',
            title: 'Prep',
            dueDate: wedDate,
            dueTime: '12:15',
            estimateMin: 30,
          ),
        ],
        habitBlocks: habitBlocks,
        prayerBlocks: prayerBlocks,
      );
      expect(CalendarScheduler.formatMinutes(nextMin), '12:45');
    });
  });

  group('Weekly Tasks Engine, Projection & Collision Tests', () {
    test('RecurrenceEngine builds, parses, formats, and matches weekly schedules accurately', () {
      final rule = RecurrenceEngine.buildWeeklyRule([
        DateTime.wednesday,
        DateTime.monday,
      ]);
      expect(rule, 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE');
      expect(RecurrenceEngine.isWeeklyRule(rule), isTrue);
      expect(RecurrenceEngine.parseWeeklyDays(rule), {
        DateTime.monday,
        DateTime.wednesday,
      });

      expect(
        RecurrenceEngine.formatHumanReadable(
          'RRULE:FREQ=WEEKLY;BYDAY=WE',
          isArabic: false,
        ),
        'Every Wed',
      );
      expect(
        RecurrenceEngine.formatHumanReadable(
          'RRULE:FREQ=WEEKLY;BYDAY=WE',
          isArabic: true,
        ),
        'كل أربعاء',
      );

      // Anchor on Wednesday 2026-12-02:
      const wedRule = 'RRULE:FREQ=WEEKLY;BYDAY=WE';
      expect(
        RecurrenceEngine.occursOnDate(
          rrule: wedRule,
          anchorDateStr: '2026-12-02',
          targetDateStr: '2026-11-25', // before anchor
        ),
        isFalse,
      );
      expect(
        RecurrenceEngine.occursOnDate(
          rrule: wedRule,
          anchorDateStr: '2026-12-02',
          targetDateStr: '2026-12-02', // anchor Wednesday
        ),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(
          rrule: wedRule,
          anchorDateStr: '2026-12-02',
          targetDateStr: '2026-12-09', // next Wednesday
        ),
        isTrue,
      );
      expect(
        RecurrenceEngine.occursOnDate(
          rrule: wedRule,
          anchorDateStr: '2026-12-02',
          targetDateStr: '2026-12-10', // Thursday
        ),
        isFalse,
      );

      // Next due date when completing Wednesday 2026-12-02 -> 2026-12-09
      expect(
        RecurrenceEngine.calculateNextDueDate(
          wedRule,
          'fixed',
          '2026-12-02',
          '2026-12-02',
        ),
        '2026-12-09',
      );

      // Checklist reset helper
      expect(
        RecurrenceEngine.uncheckMarkdownChecklists(
          '- [x] Prepare slides\n- [ ] Grade quiz\n* [X] Upload notes',
        ),
        '- [ ] Prepare slides\n- [ ] Grade quiz\n* [ ] Upload notes',
      );
    });

    test('expandTasksForDate projects weekly task onto future Wednesdays and detects task collisions', () {
      final weeklyTeaching = Task(
        id: 'teach_wed',
        title: 'Teaching Session',
        priority: 1,
        dueDate: '2026-12-02', // Wednesday
        dueTime: '08:30',
        estimateMin: 90, // 08:30 - 10:00
        recurrenceRule: 'RRULE:FREQ=WEEKLY;BYDAY=WE',
        recurrenceMode: 'fixed',
      );

      final allTasks = [weeklyTeaching];

      // Anchor Wednesday returns concrete task
      final dec02 = CalendarScheduler.expandTasksForDate(allTasks, '2026-12-02');
      expect(dec02.length, 1);
      expect(dec02.single.id, 'teach_wed');
      expect(dec02.single.isProjectedOccurrence, isFalse);

      // Next Wednesday (2026-12-09) projects virtual occurrence at 08:30 for 90m
      final dec09 = CalendarScheduler.expandTasksForDate(allTasks, '2026-12-09');
      expect(dec09.length, 1);
      expect(dec09.single.title, 'Teaching Session');
      expect(dec09.single.dueDate, '2026-12-09');
      expect(dec09.single.dueTime, '08:30');
      expect(dec09.single.estimateMin, 90);
      expect(dec09.single.isProjectedOccurrence, isTrue);
      expect(dec09.single.sourceTaskId, 'teach_wed');

      // Non-Wednesday (2026-12-10) has no occurrence
      expect(CalendarScheduler.expandTasksForDate(allTasks, '2026-12-10'), isEmpty);

      // Creating a task on future Wednesday 2026-12-16 at 09:00 collides with Teaching Session (08:30-10:00)!
      final conflict = CalendarScheduler.findConflictingTask(
        dateStr: '2026-12-16',
        startMinute: 9 * 60,
        durationMin: 30,
        existingTasks: allTasks,
      );
      expect(conflict, isNotNull);
      expect(conflict!.title, 'Teaching Session');

      final nextFree = CalendarScheduler.findNextAvailableMinute(
        dateStr: '2026-12-16',
        searchFromMinute: 9 * 60,
        durationMin: 30,
        existingTasks: allTasks,
      );
      expect(CalendarScheduler.formatMinutes(nextFree), '10:00');
    });

    test('QuickAddParser parses weekday recurrence phrases (e.g. every wednesday at 8:30 for 90m)', () {
      final parsed = QuickAddParser.parse(
        'Teaching session every wednesday at 8:30 for 90m',
      );
      expect(parsed.title, 'Teaching session');
      expect(parsed.dueTime, '08:30');
      expect(parsed.estimate, 90);
      expect(parsed.recurrence, 'RRULE:FREQ=WEEKLY;BYDAY=WE');
    });
  });

  group('Weekly Tasks UI & Calendar Widget Tests', () {
    testWidgets('CreateTaskSheet supports configuring a 90m weekly Wednesday task in desktop & mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrapWithL10n(
          CreateTaskSheet(
            isDesktop: true,
            initialDate: DateTime(2026, 12, 2), // Wednesday
            initialTime: '08:30',
            onTaskCreated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Repeat Schedule section exists with One-time & Weekly options
      expect(find.text('REPEAT SCHEDULE'), findsOneWidget);
      expect(find.byKey(const ValueKey('recurrence_mode_once')), findsOneWidget);
      expect(find.byKey(const ValueKey('recurrence_mode_weekly')), findsOneWidget);

      // Select 90m duration preset
      final preset90 = find.byKey(const ValueKey('duration_preset_90'));
      await tester.ensureVisible(preset90);
      await tester.tap(preset90);
      await tester.pumpAndSettle();
      expect(find.text('90 min'), findsOneWidget);

      // Enable Weekly mode
      final weeklyBtn = find.byKey(const ValueKey('recurrence_mode_weekly'));
      await tester.ensureVisible(weeklyBtn);
      await tester.tap(weeklyBtn);
      await tester.pumpAndSettle();

      // Weekday pills appear and Wednesday summary is shown
      expect(find.byKey(const ValueKey('weekly_day_3')), findsOneWidget); // Wednesday = 3
      expect(find.textContaining('Repeats every Wednesday'), findsOneWidget);
      expect(find.textContaining('90m'), findsWidgets);
    });

    testWidgets('DesktopCalendarScreen and MobileCalendarScreen display weekly task across future weeks', (tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final weeklyTask = Task(
        id: 't_teach_wed',
        title: 'Physics Teaching Session',
        priority: 1,
        dueDate: '2026-12-02', // Wednesday
        dueTime: '08:30',
        estimateMin: 90,
        recurrenceRule: 'RRULE:FREQ=WEEKLY;BYDAY=WE',
        recurrenceMode: 'fixed',
      );

      // Render DesktopCalendarScreen on NEXT week (Wednesday 2026-12-09)
      await tester.pumpWidget(
        _wrapWithL10n(
          DesktopCalendarScreen(
            initialTasks: [weeklyTask],
            initialHabits: const [],
            initialPrayers: const <Prayer>[],
            initialSelectedDate: DateTime(2026, 12, 9),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Physics Teaching Session'), findsOneWidget);

      // Render MobileCalendarScreen on a future Wednesday (2026-12-16)
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        _wrapWithL10n(
          MobileCalendarScreen(
            initialTasks: [weeklyTask],
            initialHabits: const [],
            initialPrayers: const <Prayer>[],
            initialSelectedDate: DateTime(2026, 12, 16),
          ),
          size: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Physics Teaching Session'), findsOneWidget);
    });
  });
}
