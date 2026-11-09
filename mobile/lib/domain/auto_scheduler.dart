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
    if (parts.length < 2) return Duration.zero;
    int h = int.tryParse(parts[0]) ?? 0;
    int m = int.tryParse(parts[1]) ?? 0;
    return Duration(hours: h.clamp(0, 23), minutes: m.clamp(0, 59));
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

    // Support both local and UTC date checks to prevent past proposals across timezones
    final localNow = DateTime.now();
    final localToday = '${localNow.year.toString().padLeft(4, '0')}-${localNow.month.toString().padLeft(2, '0')}-${localNow.day.toString().padLeft(2, '0')}';
    final utcToday = localNow.toUtc().toIso8601String().substring(0, 10);
    if ((date == localToday || date == utcToday) && now > start) {
      start = now;
    }

    // Merge overlapping busy blocks to prevent double-counting available minutes
    var sortedRawBusy = List<BusyBlock>.from(busy)..sort((a, b) => a.start.compareTo(b.start));
    var sortedBusy = <BusyBlock>[];
    for (var b in sortedRawBusy) {
      var bStart = b.start < start ? start : b.start;
      var bEnd = b.end > end ? end : b.end;
      if (bEnd <= bStart) continue;

      if (sortedBusy.isEmpty) {
        sortedBusy.add(BusyBlock(bStart, bEnd));
      } else {
        var last = sortedBusy.last;
        if (bStart <= last.end) {
          sortedBusy[sortedBusy.length - 1] = BusyBlock(
            last.start,
            bEnd > last.end ? bEnd : last.end,
          );
        } else {
          sortedBusy.add(BusyBlock(bStart, bEnd));
        }
      }
    }

    int totalBusy = 0;
    for (var b in sortedBusy) {
      totalBusy += (b.end - b.start).inMinutes;
    }

    int totalWindow = (end > start) ? (end - start).inMinutes : 0;
    result.availableMin = totalWindow - totalBusy;
    if (result.availableMin < 0) result.availableMin = 0;

    var currentPointer = start;
    int busyIndex = 0;

    for (var task in tasks) {
      int duration = (task.estimateMin ?? defaultEstimateMin).clamp(1, 1440);
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
