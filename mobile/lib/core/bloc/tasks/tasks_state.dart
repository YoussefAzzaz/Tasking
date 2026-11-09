import 'package:equatable/equatable.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';

abstract class TasksState extends Equatable {
  const TasksState();

  @override
  List<Object?> get props => [];
}

class TasksInitial extends TasksState {
  const TasksInitial();
}

class TasksLoading extends TasksState {
  const TasksLoading();
}

class TasksLoaded extends TasksState {
  final List<Task> tasks;
  final TaskFilterCriteria filterCriteria;
  final String? mutationError;

  const TasksLoaded({
    required this.tasks,
    this.filterCriteria = const TaskFilterCriteria(),
    this.mutationError,
  });

  List<Task> get filteredTasks =>
      tasks.where(filterCriteria.matches).toList();

  TasksLoaded copyWith({
    List<Task>? tasks,
    TaskFilterCriteria? filterCriteria,
    String? mutationError,
    bool clearMutationError = false,
  }) {
    return TasksLoaded(
      tasks: tasks ?? this.tasks,
      filterCriteria: filterCriteria ?? this.filterCriteria,
      mutationError: clearMutationError ? null : (mutationError ?? this.mutationError),
    );
  }

  @override
  List<Object?> get props => [tasks, filterCriteria, mutationError];
}

class TasksError extends TasksState {
  final String message;

  const TasksError(this.message);

  @override
  List<Object?> get props => [message];
}
