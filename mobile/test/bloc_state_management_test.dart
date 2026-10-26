import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/bloc/blocs.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';

class _FakeTaskRepo extends TaskRepository {
  final _ctrl = StreamController<List<Task>>.broadcast();
  List<Task> currentTasks = [];

  @override
  Stream<List<Task>> watchTasks() async* {
    yield currentTasks;
    yield* _ctrl.stream;
  }

  @override
  Future<void> addTask(Task task) async {
    currentTasks.add(task);
    _ctrl.add(List.from(currentTasks));
  }

  @override
  Future<void> toggleTaskStatus(Task task, bool isDone) async {
    final idx = currentTasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      currentTasks[idx] = task.copyWith(status: isDone ? 'done' : 'todo');
      _ctrl.add(List.from(currentTasks));
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    currentTasks.removeWhere((t) => t.id == id);
    _ctrl.add(List.from(currentTasks));
  }

  void emit(List<Task> tasks) {
    currentTasks = List.from(tasks);
    _ctrl.add(currentTasks);
  }

  void dispose() {
    _ctrl.close();
  }
}

void main() {
  group('AuthBloc Unit Tests', () {
    late AuthBloc authBloc;

    setUp(() {
      authBloc = AuthBloc();
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial', () {
      expect(authBloc.state, equals(const AuthInitial()));
    });

    test('AuthCheckRequested emits Authenticated or Unauthenticated', () async {
      authBloc.add(const AuthCheckRequested());
      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthState>(),
        ]),
      );
    });
  });

  group('FocusSessionCubit Unit Tests', () {
    late FocusSessionCubit focusCubit;

    setUp(() {
      focusCubit = FocusSessionCubit();
    });

    tearDown(() {
      focusCubit.close();
    });

    test('initial state has default 25 minutes and valid formatted time', () {
      final state = focusCubit.state;
      expect(state.remainingSeconds, equals(25 * 60));
      expect(state.totalSeconds, equals(25 * 60));
      expect(state.timeFormatted, equals('25:00'));
      expect(state.progress, equals(0.0));
      expect(state.isRunning, isFalse);
    });

    test('state copyWith updates remaining time and computes progress', () {
      final initial = focusCubit.state;
      final updated = initial.copyWith(
        remainingSeconds: 12 * 60 + 30,
        totalSeconds: 25 * 60,
      );

      expect(updated.timeFormatted, equals('12:30'));
      expect(updated.progress, closeTo(0.5, 0.05));
    });

    test('setSoundscape updates soundscape reactively', () {
      focusCubit.setSoundscape('Ocean Waves');
      expect(focusCubit.state.selectedSoundscape, equals('Ocean Waves'));
    });
  });

  group('TasksBloc Unit Tests', () {
    late _FakeTaskRepo fakeRepo;
    late TasksBloc tasksBloc;

    setUp(() {
      fakeRepo = _FakeTaskRepo();
      tasksBloc = TasksBloc(taskRepository: fakeRepo);
    });

    tearDown(() {
      tasksBloc.close();
      fakeRepo.dispose();
    });

    test('emits TasksLoading and then TasksLoaded when tasks stream emits', () async {
      final task1 = Task(id: 't1', title: 'Write BLoC Architecture');
      final task2 = Task(id: 't2', title: 'Write Clean Tests', priority: 1);

      final expectation = expectLater(
        tasksBloc.stream,
        emitsThrough(predicate<TasksState>((state) {
          if (state is TasksLoaded) {
            return state.tasks.length == 2 && state.tasks.first.title == 'Write BLoC Architecture';
          }
          return false;
        })),
      );

      fakeRepo.emit([task1, task2]);
      await expectation;
    });

    test('UpdateFilterCriteriaRequested filters tasks properly', () async {
      final taskP1 = Task(id: 't1', title: 'Urgent Task', priority: 1);
      final taskP3 = Task(id: 't2', title: 'Low Task', priority: 3);

      fakeRepo.emit([taskP1, taskP3]);
      await Future.delayed(const Duration(milliseconds: 10));

      final expectation = expectLater(
        tasksBloc.stream,
        emitsThrough(predicate<TasksState>((state) {
          if (state is TasksLoaded) {
            return state.filterCriteria.priority == 1 &&
                state.filteredTasks.length == 1 &&
                state.filteredTasks.first.id == 't1';
          }
          return false;
        })),
      );

      tasksBloc.add(const UpdateFilterCriteriaRequested(
        TaskFilterCriteria(priority: 1),
      ));

      await expectation;
    });
  });
}
