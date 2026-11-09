import 'dart:async';

sealed class DomainEvent {
  final DateTime occurredAt;
  DomainEvent({DateTime? occurredAt}) : occurredAt = occurredAt ?? DateTime.now();
}

final class TaskCreatedEvent extends DomainEvent {
  final String taskId;
  TaskCreatedEvent(this.taskId);
}

final class TaskCompletedEvent extends DomainEvent {
  final String taskId;
  final int xpEarned;
  TaskCompletedEvent(this.taskId, this.xpEarned);
}

final class LevelUpEvent extends DomainEvent {
  final int newLevel;
  LevelUpEvent(this.newLevel);
}

class DomainEvents {
  static StreamController<DomainEvent> _controller = StreamController<DomainEvent>.broadcast();

  static Stream<DomainEvent> get stream {
    if (_controller.isClosed) {
      _controller = StreamController<DomainEvent>.broadcast();
    }
    return _controller.stream;
  }

  static void emit(DomainEvent event) {
    if (_controller.isClosed) {
      _controller = StreamController<DomainEvent>.broadcast();
    }
    _controller.add(event);
  }

  static void reset() {
    if (!_controller.isClosed) {
      _controller.close();
    }
    _controller = StreamController<DomainEvent>.broadcast();
  }

  static void dispose() {
    reset();
  }
}
