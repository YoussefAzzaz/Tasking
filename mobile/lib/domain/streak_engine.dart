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

    String format(DateTime d) => d.toIso8601String().substring(0, 10);

    if (logDict.containsKey(format(pointer))) {
      if (logDict[format(pointer)] == 'done') streak++;
    }

    pointer = pointer.subtract(const Duration(days: 1));

    while (true) {
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

      pointer = pointer.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
