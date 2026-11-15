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
  }) async {
    final effectiveDate = selectedDate ?? DateTime.now();
    final dueDateStr = DateFormat('yyyy-MM-dd').format(effectiveDate);
    final effectiveDuration = CalendarScheduler.sanitizeDuration(estimateMin);

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
      final previousDueDate = taskToEdit.dueDate;
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
        clearDueDate: false,
        estimateMin: effectiveDuration,
        clearEstimateMin: false,
      );
      await _taskRepo.updateTask(updated);
      await scheduleDayTasksInRepository(dueDateStr);
      if (previousDueDate != null &&
          previousDueDate.isNotEmpty &&
          previousDueDate != dueDateStr) {
        await scheduleDayTasksInRepository(previousDueDate);
      }
      return updated;
    }

    final task = Task(
      id: IdGenerator.generateDeterministicId(
          'task_${DateTime.now().microsecondsSinceEpoch}_$title'),
      title: title,
      notes: notes.isEmpty ? null : notes,
      priority: priority == 0 ? null : priority,
      projectId: project,
      tags: allTags.isEmpty ? null : allTags.join(','),
      dueDate: dueDateStr,
      estimateMin: effectiveDuration,
    );

    await _taskRepo.addTask(task);
    await scheduleDayTasksInRepository(dueDateStr);
    return task;
  }

  /// Auto-sorts and packs incomplete tasks on [dateStr] by priority
  /// (`P1 -> P2 -> P3`) while avoiding active daily habit slots.
  Future<void> scheduleDayTasksInRepository(String dateStr) async {
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

