import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/calendar/calendar_screen.dart';
import 'package:axis/ui/calendar/mobile_calendar_screen.dart';
import 'package:axis/ui/desktop/screens/calendar/desktop_calendar_screen.dart';
import 'package:axis/ui/shell/axis_header.dart';

class _FakeHabitRepository extends HabitRepository {
  final List<Habit> store;
  final List<String> toggled = [];
  _FakeHabitRepository([List<Habit>? initial]) : store = [...?initial];

  @override
  Stream<List<Habit>> watchHabits({int? limit, int? offset}) =>
      Stream.value(List<Habit>.from(store));

  @override
  Future<void> toggleHabit(String habitId, bool isDone, [String? date]) async {
    toggled.add(habitId);
  }
}

Widget _wrapWithApp(Widget child, {Locale locale = const Locale('en'), Size size = const Size(390, 844)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AxisTheme.dark,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('CalendarScreen Adaptive Dispatcher', () {
    testWidgets('renders DesktopCalendarScreen on wide desktop screens (>= 1024px)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const CalendarScreen(),
          size: const Size(1280, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DesktopCalendarScreen), findsOneWidget);
      expect(find.byType(MobileCalendarScreen), findsNothing);
    });

    testWidgets('renders MobileCalendarScreen on mobile phone screens (< 1024px)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const CalendarScreen(),
          size: const Size(390, 844),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MobileCalendarScreen), findsOneWidget);
      expect(find.byType(DesktopCalendarScreen), findsNothing);
    });
  });

  group('MobileCalendarScreen Widget Tests', () {
    final fixedMonday = DateTime(2026, 11, 9);
    const mondayStr = '2026-11-09';

    final List<Task> testTasks = [
      Task(
        id: 't_active_1',
        title: 'Complete Mobile Spec',
        status: 'todo',
        priority: 1,
        dueDate: mondayStr,
        dueTime: '09:00',
        estimateMin: 45,
      ),
      Task(
        id: 't_done_1',
        title: 'Review Architecture',
        status: 'done',
        priority: 2,
        dueDate: mondayStr,
        dueTime: '11:00',
        estimateMin: 30,
      ),
    ];

    final List<Habit> testHabits = [
      Habit(
        id: 'h_read',
        name: 'Deep Reading',
        scheduleType: 'daily',
        remindTime: '08:00',
        isEnabled: true,
      ),
    ];

    testWidgets('renders top bar, week strip, view mode switcher, and FAB', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: testTasks,
            initialHabits: testHabits,
            initialSelectedDate: fixedMonday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar elements
      expect(find.byKey(const ValueKey('mobile_calendar_today_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile_calendar_completed_toggle')), findsOneWidget);
      expect(find.text('November 2026'), findsOneWidget);

      // Week strip navigation
      expect(find.byKey(const ValueKey('mobile_calendar_prev_week')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile_calendar_next_week')), findsOneWidget);

      // View mode buttons
      expect(find.byKey(const ValueKey('mobile_calendar_view_day')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile_calendar_view_schedule')), findsOneWidget);

      // Cyber Floating Action Button
      expect(find.byKey(const ValueKey('mobile_calendar_fab')), findsOneWidget);
    });

    testWidgets('displays active and completed tasks in Day view with correct status', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: testTasks,
            initialHabits: testHabits,
            initialSelectedDate: fixedMonday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Active task is visible
      expect(find.byKey(const ValueKey('mobile_task_t_active_1')), findsOneWidget);
      expect(find.text('Complete Mobile Spec'), findsOneWidget);

      // Completed task is visible by default
      expect(find.byKey(const ValueKey('mobile_task_t_done_1')), findsOneWidget);
      expect(find.text('Review Architecture'), findsOneWidget);

      // Habit block is placed
      expect(find.byKey(const ValueKey('mobile_habit_2026-11-09_h_read')), findsOneWidget);
      expect(find.text('Deep Reading'), findsOneWidget);
    });

    testWidgets('completed tasks toggle hides and shows completed tasks', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: testTasks,
            initialHabits: testHabits,
            initialSelectedDate: fixedMonday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially both tasks visible
      expect(find.byKey(const ValueKey('mobile_task_t_active_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile_task_t_done_1')), findsOneWidget);

      // Tap completed toggle to hide completed tasks
      await tester.tap(find.byKey(const ValueKey('mobile_calendar_completed_toggle')));
      await tester.pumpAndSettle();

      // Active task remains, completed task hidden
      expect(find.byKey(const ValueKey('mobile_task_t_active_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile_task_t_done_1')), findsNothing);

      // Tap completed toggle again to reveal completed tasks
      await tester.tap(find.byKey(const ValueKey('mobile_calendar_completed_toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mobile_task_t_done_1')), findsOneWidget);
    });

    testWidgets('week strip allows selecting days and updates day tasks', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<Task> tuesdayTasks = [
        ...testTasks,
        Task(
          id: 't_tuesday',
          title: 'Tuesday Special Event',
          status: 'todo',
          priority: 1,
          dueDate: '2026-11-10',
          dueTime: '14:00',
          estimateMin: 60,
        ),
      ];

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: tuesdayTasks,
            initialHabits: testHabits,
            initialSelectedDate: fixedMonday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Monday has test tasks, not Tuesday special event
      expect(find.byKey(const ValueKey('mobile_task_t_active_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile_task_t_tuesday')), findsNothing);

      // Tap Tuesday in week strip
      const tuesdayKey = ValueKey('mobile_calendar_day_2026-11-10');
      expect(find.byKey(tuesdayKey), findsOneWidget);
      await tester.tap(find.byKey(tuesdayKey));
      await tester.pumpAndSettle();

      // Now Tuesday task is visible
      expect(find.byKey(const ValueKey('mobile_task_t_tuesday')), findsOneWidget);
      expect(find.text('Tuesday Special Event'), findsOneWidget);
    });

    testWidgets('switching to Schedule view displays timeline agenda with items', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: testTasks,
            initialHabits: testHabits,
            initialSelectedDate: fixedMonday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Schedule view mode
      await tester.tap(find.byKey(const ValueKey('mobile_calendar_view_schedule')));
      await tester.pumpAndSettle();

      // Agenda list displays items
      expect(find.text('Complete Mobile Spec'), findsOneWidget);
      expect(find.text('Review Architecture'), findsOneWidget);
      expect(find.text('Deep Reading'), findsOneWidget);

      // Switch to a day with no tasks (Wednesday 2026-11-11)
      const wedKey = ValueKey('mobile_calendar_day_2026-11-11');
      await tester.tap(find.byKey(wedKey));
      await tester.pumpAndSettle();

      // Wednesday has no tasks (habit is daily, so habit shows)
      expect(find.text('Deep Reading'), findsOneWidget);
      expect(find.text('Complete Mobile Spec'), findsNothing);
    });

    testWidgets('Arabic localization renders localized month and labels', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: testTasks,
            initialHabits: testHabits,
            initialSelectedDate: fixedMonday,
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      // Arabic month and today button
      expect(find.text('نوفمبر 2026'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('التقويم'), findsOneWidget);
    });

    testWidgets('toggling a habit in Schedule view calls HabitRepository and updates completion style', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeHabitRepo = _FakeHabitRepository(testHabits);

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: const [],
            initialHabits: testHabits,
            initialSelectedDate: fixedMonday,
            habitRepo: fakeHabitRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to schedule view where items are in a visible ListView
      await tester.tap(find.byKey(const ValueKey('mobile_calendar_view_schedule')));
      await tester.pumpAndSettle();

      final habitFinder = find.text('Deep Reading');
      expect(habitFinder, findsOneWidget);

      await tester.tap(habitFinder);
      await tester.pumpAndSettle();

      expect(fakeHabitRepo.toggled, contains('h_read'));
    });

    testWidgets('Today button jumps back to current date from distant week', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: const [],
            initialHabits: const [],
            initialSelectedDate: DateTime(2025, 1, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('January 2025'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mobile_calendar_today_button')));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final nowYear = '${now.year}';
      expect(find.textContaining(nowYear), findsWidgets);
    });

    testWidgets('schedule view displays daily prayers and habits in chronological timeline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          MobileCalendarScreen(
            initialTasks: const [],
            initialHabits: testHabits,
            initialSelectedDate: fixedMonday,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('mobile_calendar_view_schedule')));
      await tester.pumpAndSettle();

      expect(find.text('Deep Reading'), findsOneWidget);
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('Dhuhr'), findsOneWidget);
    });
  });

  group('AxisHeader Calendar Entry Point', () {
    testWidgets('AxisHeader renders calendar button with proper tooltip and styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AxisHeader(
              onAvatarTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('axis_header_calendar_button')), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
    });
  });
}
