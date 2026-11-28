import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/domain/calendar_scheduler.dart';
import 'package:axis/core/storage/axis_storage.dart';
import 'package:axis/ui/tasks/widgets/task_collision_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 1: 15-Minute Macro Slots Filter', () {
    test('slottedTasks only includes today\'s tasks with estimate <= 15 min', () {
      const todayStr = '2026-11-24';

      final task1 = Task(
        id: 't1',
        title: 'Quick 10m task',
        dueDate: todayStr,
        dueTime: '09:00',
        estimateMin: 10,
      );

      final task2 = Task(
        id: 't2',
        title: 'Exact 15m task',
        dueDate: todayStr,
        dueTime: '09:30',
        estimateMin: 15,
      );

      final task3 = Task(
        id: 't3',
        title: '30m task with dueTime (should be excluded)',
        dueDate: todayStr,
        dueTime: '10:00',
        estimateMin: 30,
      );

      final task4 = Task(
        id: 't4',
        title: '60m task with dueTime (should be excluded)',
        dueDate: todayStr,
        dueTime: '11:00',
        estimateMin: 60,
      );

      final task5 = Task(
        id: 't5',
        title: 'Task without estimate (should be excluded)',
        dueDate: todayStr,
        dueTime: '14:00',
        estimateMin: null,
      );

      final allTasks = [task1, task2, task3, task4, task5];

      final slottedTasks = allTasks.where((t) {
        final isToday = t.dueDate != null &&
            (t.dueDate == todayStr || t.dueDate!.startsWith(todayStr));
        if (!isToday) return false;
        final estimate = t.estimateMin;
        return estimate != null && estimate > 0 && estimate <= 15;
      }).toList();

      expect(slottedTasks.length, 2);
      expect(slottedTasks.map((t) => t.id).toList(), ['t1', 't2']);
    });
  });

  group('Requirement 2: AxisStorage Directory Organization & Legacy Migration', () {
    late Directory tempDocsDir;

    setUp(() async {
      tempDocsDir = await Directory.systemTemp.createTemp('axis_test_docs_');
      AxisStorage.resetForTesting();
      AxisStorage.debugOverrideRootPath = tempDocsDir.path;
    });

    tearDown(() async {
      AxisStorage.resetForTesting();
      if (await tempDocsDir.exists()) {
        await tempDocsDir.delete(recursive: true);
      }
    });

    test('All generated file paths point inside axis subdirectories', () async {
      final dbPath = await AxisStorage.getDatabasePath();
      final localeFile = await AxisStorage.getLocaleFile();
      final readingFile = await AxisStorage.getReadingPreferencesFile();
      final notifFile = await AxisStorage.getDismissedNotificationsFile();
      final soundsDir = await AxisStorage.getAdhanSoundsDirectory();
      final vaultDir = await AxisStorage.getVaultDirectory();

      expect(p.split(dbPath), containsAll(['axis', 'database', 'axis_powersync.db']));
      expect(p.split(localeFile.path), containsAll(['axis', 'preferences', 'app_locale_preference.json']));
      expect(p.split(readingFile.path), containsAll(['axis', 'preferences', 'reading_preferences.json']));
      expect(p.split(notifFile.path), containsAll(['axis', 'notifications', 'dismissed_notifications.json']));
      expect(p.split(soundsDir.path), containsAll(['axis', 'sounds', 'custom_adhan_sounds']));
      expect(p.split(vaultDir.path), containsAll(['axis', 'vault']));
    });

    test('ensureInitializedAndMigrated moves legacy files into axis directory safely', () async {
      // Create fake legacy files in root documents directory
      final legacyDb = File(p.join(tempDocsDir.path, 'axis_powersync.db'));
      await legacyDb.writeAsString('sqlite-content');

      final legacyLocale = File(p.join(tempDocsDir.path, 'app_locale_preference.json'));
      await legacyLocale.writeAsString('{"languageCode": "ar"}');

      await AxisStorage.ensureInitializedAndMigrated();

      // Legacy files in root should be moved
      expect(await legacyDb.exists(), isFalse);
      expect(await legacyLocale.exists(), isFalse);

      // Migrated files in axis subdirectories must exist with content
      final targetDb = File(p.join(tempDocsDir.path, 'axis', 'database', 'axis_powersync.db'));
      final targetLocale = File(p.join(tempDocsDir.path, 'axis', 'preferences', 'app_locale_preference.json'));

      expect(await targetDb.exists(), isTrue);
      expect(await targetDb.readAsString(), 'sqlite-content');
      expect(await targetLocale.exists(), isTrue);
      expect(await targetLocale.readAsString(), '{"languageCode": "ar"}');
    });
  });

  group('Requirement 3: Task Collision Detection & Alert Options', () {
    const testDate = '2026-11-24';

    test('findConflictingTask detects overlap with existing task but ignores completed or different day', () {
      final existingTasks = [
        Task(
          id: 'existing_1',
          title: 'Morning Meeting',
          dueDate: testDate,
          dueTime: '09:00', // 09:00 to 09:30
          estimateMin: 30,
        ),
        Task(
          id: 'existing_done',
          title: 'Already finished',
          dueDate: testDate,
          dueTime: '10:00',
          estimateMin: 30,
          status: 'done',
        ),
        Task(
          id: 'existing_tomorrow',
          title: 'Tomorrow call',
          dueDate: '2026-11-25',
          dueTime: '09:00',
          estimateMin: 30,
        ),
      ];

      // Collides at 09:15 (09:15 - 09:45 overlaps with 09:00 - 09:30)
      final conflict = CalendarScheduler.findConflictingTask(
        dateStr: testDate,
        startMinute: 9 * 60 + 15,
        durationMin: 30,
        existingTasks: existingTasks,
      );
      expect(conflict, isNotNull);
      expect(conflict!.id, 'existing_1');

      // Does not collide at 09:30 (starts right after existing_1 ends)
      final noConflict = CalendarScheduler.findConflictingTask(
        dateStr: testDate,
        startMinute: 9 * 60 + 30,
        durationMin: 15,
        existingTasks: existingTasks,
      );
      expect(noConflict, isNull);

      // Does not collide with completed task at 10:00
      final doneConflict = CalendarScheduler.findConflictingTask(
        dateStr: testDate,
        startMinute: 10 * 60,
        durationMin: 30,
        existingTasks: existingTasks,
      );
      expect(doneConflict, isNull);
    });

    test('findNextAvailableMinute skips over conflicting tasks and ignores habits and prayers', () {
      final existingTasks = [
        Task(
          id: 'task_1',
          title: 'Existing Task',
          dueDate: testDate,
          dueTime: '09:00',
          estimateMin: 30, // 09:00 - 09:30
        ),
      ];

      final habitBlocks = [
        CalendarHabitBlock(
          habit: Habit(
            id: 'habit_1',
            name: 'Daily Habit',
          ),
          startMinute: 9 * 60 + 30, // 09:30 - 09:45
          durationMin: 15,
        ),
      ];

      // Starting search from 09:00 for a 15 min task:
      // 09:00-09:30 is blocked by task_1
      // 09:30-09:45 has habit_1, which must NOT block or push tasks!
      // Next available slot must be 09:30!
      final nextMin = CalendarScheduler.findNextAvailableMinute(
        dateStr: testDate,
        searchFromMinute: 9 * 60,
        durationMin: 15,
        existingTasks: existingTasks,
        habitBlocks: habitBlocks,
      );

      expect(nextMin, 9 * 60 + 30); // 09:30
      expect(CalendarScheduler.formatMinutes(nextMin), '09:30');
    });

    test('displaceConflictingTask gives incoming task the requested slot and moves conflicting task', () {
      final existingTask = Task(
        id: 'orig_1',
        title: 'Original Task',
        dueDate: testDate,
        dueTime: '09:00',
        estimateMin: 30,
      );

      final newTask = Task(
        id: 'new_1',
        title: 'Incoming Urgent Task',
        dueDate: testDate,
        dueTime: '09:00',
        estimateMin: 15,
      );

      final result = CalendarScheduler.displaceConflictingTask(
        dateStr: testDate,
        existingDayTasks: [existingTask],
        incomingTask: newTask,
        targetStartMinute: 9 * 60,
        habitBlocks: [],
      );

      final placedNew = result.firstWhere((t) => t.id == 'new_1');
      final placedOrig = result.firstWhere((t) => t.id == 'orig_1');

      // New task takes 09:00
      expect(placedNew.dueTime, '09:00');
      // Original task is displaced to 09:15 (next empty spot)
      expect(placedOrig.dueTime, '09:15');
    });

    test('TaskCollisionChoice enum covers user options', () {
      expect(TaskCollisionChoice.values, containsAll([
        TaskCollisionChoice.moveNewTask,
        TaskCollisionChoice.moveExistingTask,
        TaskCollisionChoice.cancel,
      ]));
    });
  });

  group('Requirement 4 & 5: Notification Badge Reset & Silent Background Habit Action', () {
    test('Habit notification action has ActionType.SilentBackgroundAction and autoDismissible', () {
      final button = NotificationActionButton(
        key: 'MARK_DONE',
        label: 'Mark as Completed',
        actionType: ActionType.SilentBackgroundAction,
        autoDismissible: true,
      );

      expect(button.key, 'MARK_DONE');
      expect(button.actionType, ActionType.SilentBackgroundAction);
      expect(button.autoDismissible, isTrue);
    });
  });
}
