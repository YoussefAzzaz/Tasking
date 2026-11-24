import 'package:intl/intl.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/powersync_db.dart' show isDatabaseInitialized;
import 'package:axis/data/prayers/prayer_model.dart';
import 'package:axis/data/prayers/prayer_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/calendar_scheduler.dart';
import 'package:axis/domain/id_generator.dart';

/// Application service responsible for persisting task creations and updates,
/// transparently auto-registering user-typed projects and tags, and
/// auto-scheduling day tasks onto the calendar by priority.
class TaskFormService {
  final ProjectRepository _projectRepo;
  final TagRepository _tagRepo;
  final TaskRepository _taskRepo;
  final HabitRepository _habitRepo;
  final PrayerRepository _prayerRepo;
  final bool Function() _isInitialized;

  TaskFormService({
    ProjectRepository? projectRepo,
    TagRepository? tagRepo,
    TaskRepository? taskRepo,
    HabitRepository? habitRepo,
    PrayerRepository? prayerRepo,
    bool Function()? isInitialized,
  })  : _projectRepo = projectRepo ?? ProjectRepository(),
        _tagRepo = tagRepo ?? TagRepository(),
        _taskRepo = taskRepo ?? TaskRepository(),
        _habitRepo = habitRepo ?? HabitRepository(),
        _prayerRepo = prayerRepo ?? PrayerRepository(),
        _isInitialized = isInitialized ?? (() => isDatabaseInitialized);

  /// Validates and saves a task (create or update).
  Future<Task> saveTask({
    Task? taskToEdit,
    required String title,
    required String notes,
    required int? priority,
    required String? rawProject,
    required Set<String> selectedTags,
    required String additionalTag,
    required DateTime? selectedDate,
    required int? estimateMin,
    required List<Project> existingProjects,
    String? dueTime,
    DateTime? referenceTime,
    bool displaceConflicting = false,
  }) async {
    final now = referenceTime ?? DateTime.now();
    final String? dueDateStr = selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(selectedDate)
        : null;
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final isToday = dueDateStr != null && dueDateStr == todayStr;
    final effectiveDuration = CalendarScheduler.sanitizeDuration(estimateMin);

    final String? effectiveDueTime;
    if (dueDateStr == null) {
      effectiveDueTime = null;
    } else if (dueTime != null && dueTime.trim().isNotEmpty) {
      effectiveDueTime = dueTime.trim();
    } else if (taskToEdit != null) {
      effectiveDueTime = taskToEdit.dueTime;
    } else if (isToday) {
      effectiveDueTime = CalendarScheduler.defaultTodayTaskTimeString(now);
    } else {
      effectiveDueTime = null;
    }

    final allTags = Set<String>.from(selectedTags);
    if (additionalTag.trim().isNotEmpty) {
      allTags.add(additionalTag.trim().replaceAll('@', ''));
    }

    final cleanRaw = rawProject?.trim().isNotEmpty == true
        ? rawProject!.trim().replaceAll('#', '')
        : null;

    final project =
        (cleanRaw == null || cleanRaw.isEmpty || cleanRaw == 'Inbox')
            ? null
            : cleanRaw;

    // If project was typed by user and doesn't exist yet, save it as a new Project
    if (project != null) {
      final exists = existingProjects.any(
        (p) => p.name.toLowerCase() == project.toLowerCase(),
      );
      if (!exists) {
        final newProject = Project(
          id: IdGenerator.generateDeterministicId('proj_$project'),
          name: project,
          color: '#6366F1',
        );
        try {
          await _projectRepo.addProject(newProject);
        } catch (_) {}
      }
    }

    // Persist any user-defined tags so they can be viewed and managed
    for (final tag in allTags) {
      final clean = tag.trim().replaceAll('@', '');
      if (clean.isNotEmpty) {
        await _tagRepo.addTag(clean);
      }
    }

    if (taskToEdit != null) {
      final updated = taskToEdit.copyWith(
        title: title,
        notes: notes.isEmpty ? null : notes,
        clearNotes: notes.isEmpty,
        priority: priority == 0 ? null : priority,
        clearPriority: priority == 0 || priority == null,
        projectId: project,
        clearProjectId: project == null,
        tags: allTags.isEmpty ? null : allTags.join(','),
        clearTags: allTags.isEmpty,
        dueDate: dueDateStr,
        clearDueDate: dueDateStr == null,
        dueTime: effectiveDueTime,
        clearDueTime: effectiveDueTime == null,
        estimateMin: effectiveDuration,
        clearEstimateMin: false,
      );
      await _taskRepo.updateTask(updated);
      return updated;
    }

    final rawNewTask = Task(
      id: IdGenerator.generateDeterministicId(
          'task_${DateTime.now().microsecondsSinceEpoch}_$title'),
      title: title,
      notes: notes.isEmpty ? null : notes,
      priority: priority == 0 ? null : priority,
      projectId: project,
      tags: allTags.isEmpty ? null : allTags.join(','),
      dueDate: dueDateStr,
      dueTime: effectiveDueTime,
      estimateMin: effectiveDuration,
    );

    // If task has no due date, it is an unscheduled task that does not appear on the calendar or today's schedule
    if (dueDateStr == null) {
      await _taskRepo.addTask(rawNewTask);
      return rawNewTask;
    }

    if (!displaceConflicting && dueTime != null) {
      // Preserve existing tasks completely when user explicitly specified a time without displacing existing tasks
      await _taskRepo.addTask(rawNewTask);
      return rawNewTask;
    }

    try {
      final allTasks = await _taskRepo.getTasks();
      final existingDayTasks = allTasks
          .where((t) => t.dueDate == dueDateStr && !t.isCompleted)
          .toList();

      final habits = await _habitRepo
          .watchHabits()
          .first
          .timeout(const Duration(seconds: 2), onTimeout: () => const <Habit>[]);
      final habitBlocks = CalendarScheduler.buildDailyHabitBlocks(habits);

      List<Prayer> prayers = const [];
      try {
        prayers = await _prayerRepo
            .watchPrayers()
            .first
            .timeout(const Duration(seconds: 2), onTimeout: () => const <Prayer>[]);
      } catch (_) {}
      final prayerBlocks = CalendarScheduler.buildDailyPrayerBlocks(prayers);

      final startMin = CalendarScheduler.parseTimeToMinutes(effectiveDueTime) ??
          (isToday ? CalendarScheduler.defaultTodayTaskStartMinute(now) : CalendarScheduler.defaultDayStartMinutes);

      final List<Task> scheduled;
      if (displaceConflicting) {
        scheduled = CalendarScheduler.displaceConflictingTask(
          dateStr: dueDateStr,
          existingDayTasks: existingDayTasks,
          incomingTask: rawNewTask,
          targetStartMinute: startMin,
          habitBlocks: habitBlocks,
          prayerBlocks: prayerBlocks,
        );
      } else {
        scheduled = CalendarScheduler.scheduleNewTaskForDay(
          dateStr: dueDateStr,
          existingDayTasks: existingDayTasks,
          newTask: rawNewTask,
          habitBlocks: habitBlocks,
          prayerBlocks: prayerBlocks,
          referenceTime: now,
        );
      }

      final finalNewTask = scheduled.firstWhere((t) => t.id == rawNewTask.id);
      await _taskRepo.addTask(finalNewTask);

      // Update any lower-priority existing tasks that were moved down:
      for (final t in scheduled) {
        if (t.id != finalNewTask.id) {
          final orig = existingDayTasks.where((e) => e.id == t.id).firstOrNull;
          if (orig == null || orig.dueTime != t.dueTime) {
            await _taskRepo.updateTask(t);
          }
        }
      }
      return finalNewTask;
    } catch (_) {
      await _taskRepo.addTask(rawNewTask);
      return rawNewTask;
    }
  }

  /// Auto-sorts and packs incomplete tasks on [dateStr] by priority
  /// (`P1 -> P2 -> P3`) while avoiding active daily habit slots.
  Future<void> scheduleDayTasksInRepository(String dateStr, [DateTime? referenceTime]) async {
    if (!_isInitialized()) return;
    try {
      final allTasks = await _taskRepo.getTasks();
      final habits = await _habitRepo
          .watchHabits()
          .first
          .timeout(const Duration(seconds: 2), onTimeout: () => const <Habit>[]);
      final habitBlocks = CalendarScheduler.buildDailyHabitBlocks(habits);

      List<Prayer> prayers = const [];
      try {
        prayers = await _prayerRepo
            .watchPrayers()
            .first
            .timeout(const Duration(seconds: 2), onTimeout: () => const <Prayer>[]);
      } catch (_) {}
      final prayerBlocks = CalendarScheduler.buildDailyPrayerBlocks(prayers);

      final dayTasks = allTasks
          .where((t) => t.dueDate == dateStr && !t.isCompleted)
          .toList();
      if (dayTasks.isEmpty) return;

      final packed = CalendarScheduler.sortAndPackDayByPriority(
        dateStr: dateStr,
        dayTasks: dayTasks,
        habitBlocks: habitBlocks,
        prayerBlocks: prayerBlocks,
        referenceTime: referenceTime,
      );

      final origById = {for (final t in dayTasks) t.id: t};
      for (final updated in packed) {
        final orig = origById[updated.id];
        if (orig == null ||
            orig.dueTime != updated.dueTime ||
            orig.dueDate != updated.dueDate ||
            orig.estimateMin != updated.estimateMin) {
          await _taskRepo.updateTask(updated);
        }
      }
    } catch (_) {}
  }
}

