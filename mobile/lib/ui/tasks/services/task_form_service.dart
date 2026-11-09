import 'package:intl/intl.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/id_generator.dart';

/// Application service responsible for persisting task creations and updates,
/// as well as transparently auto-registering user-typed projects and tags.
class TaskFormService {
  final ProjectRepository _projectRepo;
  final TagRepository _tagRepo;
  final TaskRepository _taskRepo;

  TaskFormService({
    ProjectRepository? projectRepo,
    TagRepository? tagRepo,
    TaskRepository? taskRepo,
  })  : _projectRepo = projectRepo ?? ProjectRepository(),
        _tagRepo = tagRepo ?? TagRepository(),
        _taskRepo = taskRepo ?? TaskRepository();

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
    final dueDateStr = selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(selectedDate)
        : null;

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
      final updated = Task(
        id: taskToEdit.id,
        title: title,
        notes: notes.isEmpty ? null : notes,
        status: taskToEdit.status,
        priority: priority == 0 ? null : priority,
        projectId: project,
        tags: allTags.isEmpty ? null : allTags.join(','),
        dueDate: dueDateStr,
        dueTime: taskToEdit.dueTime,
        estimateMin: estimateMin,
        recurrenceRule: taskToEdit.recurrenceRule,
        recurrenceMode: taskToEdit.recurrenceMode,
      );
      await _taskRepo.updateTask(updated);
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
      estimateMin: estimateMin,
    );

    await _taskRepo.addTask(task);
    return task;
  }
}

