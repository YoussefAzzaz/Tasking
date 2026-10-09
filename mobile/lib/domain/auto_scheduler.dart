class BusyBlock {
  final Duration start;
  final Duration end;

  BusyBlock(this.start, this.end);
}

class SchedulableTask {
  final String id;
  final int? estimateMin;

  SchedulableTask(this.id, this.estimateMin);
}

class ProposedSlot {
  final String id;
  final String start;
  final String end;

  ProposedSlot(this.id, this.start, this.end);

  Map<String, dynamic> toJson() => {'id': id, 'start': start, 'end': end};
}

class SchedulerResult {
  List<ProposedSlot> proposed = [];
  List<String> unplaced = [];
  int availableMin = 0;
  int plannedMin = 0;
}

class AutoScheduler {
  static Duration _parseTime(String time) {
    var parts = time.split(':');
    return Duration(hours: int.parse(parts[0]), minutes: int.parse(parts[1]));
  }

  static String _formatTime(Duration d) {
    String h = d.inHours.toString().padLeft(2, '0');
    String m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static SchedulerResult schedule(
      String date,
      String nowTime,
      String workStart,
      String workEnd,
      int bufferMin,
      int defaultEstimateMin,
      List<BusyBlock> busy,
      List<SchedulableTask> tasks) {
    var result = SchedulerResult();

    var start = _parseTime(workStart);
    var end = _parseTime(workEnd);
    var now = _parseTime(nowTime);

    // DateTime logic to check if 'date' is today
    var today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    if (date == today && now > start) {
      start = now;
    }

    var sortedBusy = List<BusyBlock>.from(busy)..sort((a, b) => a.start.compareTo(b.start));

    int totalBusy = 0;
    for (var b in sortedBusy) {
      var bStart = b.start < start ? start : b.start;
      var bEnd = b.end > end ? end : b.end;
      if (bEnd > bStart) {
        totalBusy += (bEnd - bStart).inMinutes;
      }
    }

    int totalWindow = (end > start) ? (end - start).inMinutes : 0;
    result.availableMin = totalWindow - totalBusy;

    var currentPointer = start;
    int busyIndex = 0;

    for (var task in tasks) {
      int duration = task.estimateMin ?? defaultEstimateMin;
      bool placed = false;

      while (currentPointer + Duration(minutes: duration) <= end) {
        while (busyIndex < sortedBusy.length && sortedBusy[busyIndex].end <= currentPointer) {
          busyIndex++;
        }

        if (busyIndex < sortedBusy.length &&
            sortedBusy[busyIndex].start < currentPointer + Duration(minutes: duration)) {
          currentPointer = sortedBusy[busyIndex].end;
        } else {
          var slotEnd = currentPointer + Duration(minutes: duration);
          result.proposed.add(ProposedSlot(
            task.id,
            _formatTime(currentPointer),
            _formatTime(slotEnd),
          ));
          result.plannedMin += duration;
          currentPointer = slotEnd + Duration(minutes: bufferMin);
          placed = true;
          break;
        }
      }

      if (!placed) {
        result.unplaced.add(task.id);
      }
    }

    return result;
  }
}
