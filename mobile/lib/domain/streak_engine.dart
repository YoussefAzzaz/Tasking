class StreakLog {
  final String date;
  final String status;
  StreakLog(this.date, this.status);
}

class StreakEngine {
  static int calculateStreak(String scheduleType, List<StreakLog> logs, String currentDateStr) {
    if (logs.isEmpty) return 0;
    
    DateTime? currentDate = DateTime.tryParse(currentDateStr);
    if (currentDate == null) return 0;

    var logDict = {for (var log in logs) log.date: log.status};
    
    int streak = 0;
    DateTime pointer = currentDate;

    String format(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    if (logDict.containsKey(format(pointer))) {
      final currentStatus = logDict[format(pointer)];
      if (currentStatus == 'done') {
        streak++;
      } else if (currentStatus == 'failed' || currentStatus == 'missed') {
        return 0; // Explicit failure today breaks active streak
      }
    }

    // DST-safe calendar day subtraction
    pointer = DateTime(pointer.year, pointer.month, pointer.day - 1);

    int safetyIteration = 0;
    final maxIterations = logs.length * 7 + 366;

    while (safetyIteration++ < maxIterations) {
      String dateKey = format(pointer);
      
      bool isScheduled = true;
      if (scheduleType == 'weekdays') {
        isScheduled = pointer.weekday != DateTime.saturday && pointer.weekday != DateTime.sunday;
      }

      if (logDict.containsKey(dateKey)) {
        var status = logDict[dateKey];
        if (status == 'done') {
          streak++;
        } else if (status == 'skipped') {
          // skipped doesn't break streak
        } else {
          break;
        }
      } else {
        if (isScheduled) {
          break;
        }
      }

      // DST-safe calendar day subtraction
      pointer = DateTime(pointer.year, pointer.month, pointer.day - 1);
    }

    return streak;
  }
}
