import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';
import 'tasks_event.dart';
import 'tasks_state.dart';

export 'tasks_event.dart';
export 'tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  final TaskRepository _taskRepository;
  StreamSubscription<List<Task>>? _tasksSubscription;

  TasksBloc({TaskRepository? taskRepository})
      : _taskRepository = taskRepository ?? TaskRepository(),
        super(const TasksInitial()) {
    on<LoadTasksRequested>(_onLoadTasksRequested);
    on<TaskUpdatedEvent>(_onTaskUpdatedEvent);
    on<CreateTaskRequested>(_onCreateTaskRequested);
    on<ToggleTaskStatusRequested>(_onToggleTaskStatusRequested);
    on<DeleteTaskRequested>(_onDeleteTaskRequested);
    on<UpdateFilterCriteriaRequested>(_onUpdateFilterCriteriaRequested);

    add(const LoadTasksRequested());
  }

  Future<void> _onLoadTasksRequested(
    LoadTasksRequested event,
    Emitter<TasksState> emit,
  ) async {
    emit(const TasksLoading());
    await _tasksSubscription?.cancel();
    _tasksSubscription = _taskRepository.watchTasks().listen(
      (tasks) => add(TaskUpdatedEvent(tasks)),
      onError: (err) => emit(TasksError(err.toString())),
    );
  }

  void _onTaskUpdatedEvent(
    TaskUpdatedEvent event,
    Emitter<TasksState> emit,
  ) {
    final currentCriteria = state is TasksLoaded
        ? (state as TasksLoaded).filterCriteria
        : const TaskFilterCriteria();
    emit(TasksLoaded(tasks: event.tasks, filterCriteria: currentCriteria));
  }

  Future<void> _onCreateTaskRequested(
    CreateTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      await _taskRepository.addTask(event.task);
    } catch (e) {
      emit(TasksError(e.toString()));
    }
  }

  Future<void> _onToggleTaskStatusRequested(
    ToggleTaskStatusRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      await _taskRepository.toggleTaskStatus(event.task, event.isDone);
    } catch (e) {
      emit(TasksError(e.toString()));
    }
  }

  Future<void> _onDeleteTaskRequested(
    DeleteTaskRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      await _taskRepository.deleteTask(event.taskId);
    } catch (e) {
      emit(TasksError(e.toString()));
    }
  }

  void _onUpdateFilterCriteriaRequested(
    UpdateFilterCriteriaRequested event,
    Emitter<TasksState> emit,
  ) {
    if (state is TasksLoaded) {
      final current = state as TasksLoaded;
      emit(TasksLoaded(tasks: current.tasks, filterCriteria: event.criteria));
    }
  }

  @override
  Future<void> close() {
    _tasksSubscription?.cancel();
    return super.close();
  }
}
