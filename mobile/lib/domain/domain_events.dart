import 'dart:async';

abstract class DomainEvent {}

class TaskCreatedEvent extends DomainEvent {
  final String taskId;
  TaskCreatedEvent(this.taskId);
}

class TaskCompletedEvent extends DomainEvent {
  final String taskId;
  final int xpEarned;
  TaskCompletedEvent(this.taskId, this.xpEarned);
}

class LevelUpEvent extends DomainEvent {
  final int newLevel;
  LevelUpEvent(this.newLevel);
}

class DomainEvents {
  static final StreamController<DomainEvent> _controller = StreamController<DomainEvent>.broadcast();

  static Stream<DomainEvent> get stream => _controller.stream;

  static void emit(DomainEvent event) {
    _controller.add(event);
  }

  static void dispose() {
    _controller.close();
  }
}
