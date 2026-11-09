import 'package:equatable/equatable.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';

abstract class TasksEvent extends Equatable {
  const TasksEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasksRequested extends TasksEvent {
  const LoadTasksRequested();
}

class TaskUpdatedEvent extends TasksEvent {
  final List<Task> tasks;

  const TaskUpdatedEvent(this.tasks);

  @override
  List<Object?> get props => [tasks];
}

class TaskLoadFailedEvent extends TasksEvent {
  final String error;

  const TaskLoadFailedEvent(this.error);

  @override
  List<Object?> get props => [error];
}

class CreateTaskRequested extends TasksEvent {
  final Task task;

  const CreateTaskRequested(this.task);

  @override
  List<Object?> get props => [task];
}

class ToggleTaskStatusRequested extends TasksEvent {
  final Task task;
  final bool isDone;

  const ToggleTaskStatusRequested({required this.task, required this.isDone});

  @override
  List<Object?> get props => [task, isDone];
}

class DeleteTaskRequested extends TasksEvent {
  final String taskId;

  const DeleteTaskRequested(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class UpdateFilterCriteriaRequested extends TasksEvent {
  final TaskFilterCriteria criteria;

  const UpdateFilterCriteriaRequested(this.criteria);

  @override
  List<Object?> get props => [criteria];
}
