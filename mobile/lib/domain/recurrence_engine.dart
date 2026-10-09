class RecurrenceEngine {
  static String calculateNextDueDate(
      String rrule, String mode, String currentDueDateStr, String completionDateStr) {
    if (rrule.isEmpty || !rrule.startsWith('RRULE:')) return currentDueDateStr;

    DateTime? currentDueDate = DateTime.tryParse(currentDueDateStr);
    DateTime? completionDate = DateTime.tryParse(completionDateStr);

    if (currentDueDate == null || completionDate == null) return currentDueDateStr;

    // Parse RRULE
    var parts = rrule.substring(6).split(';');
    var rules = <String, String>{};
    for (var p in parts) {
      var kv = p.split('=');
      if (kv.length == 2) rules[kv[0]] = kv[1];
    }

    String freq = rules['FREQ'] ?? 'DAILY';
    int interval = int.tryParse(rules['INTERVAL'] ?? '1') ?? 1;

    DateTime baseDate = mode == 'after_completion' ? completionDate : currentDueDate;
    DateTime nextDate = baseDate;

    if (freq == 'DAILY') {
      nextDate = baseDate.add(Duration(days: interval));
    } else if (freq == 'WEEKLY') {
      if (rules.containsKey('BYDAY')) {
        var days = rules['BYDAY']!.split(',');
        var dayMap = {
          'MO': DateTime.monday,
          'TU': DateTime.tuesday,
          'WE': DateTime.wednesday,
          'TH': DateTime.thursday,
          'FR': DateTime.friday,
          'SA': DateTime.saturday,
          'SU': DateTime.sunday,
        };

        var targetDays = days.map((d) => dayMap[d]).toList();

        for (int i = 1; i <= 7 * interval; i++) {
          var candidate = baseDate.add(Duration(days: i));
          if (targetDays.contains(candidate.weekday)) {
            nextDate = candidate;
            break;
          }
        }
      } else {
        nextDate = baseDate.add(Duration(days: 7 * interval));
      }
    } else if (freq == 'MONTHLY') {
      if (rules.containsKey('BYMONTHDAY')) {
        int day = int.parse(rules['BYMONTHDAY']!);
        nextDate = DateTime(baseDate.year, baseDate.month + interval, 1);
        int daysInMonth = DateTime(nextDate.year, nextDate.month + 1, 0).day;
        nextDate = DateTime(nextDate.year, nextDate.month, day > daysInMonth ? daysInMonth : day);
      } else {
        nextDate = DateTime(baseDate.year, baseDate.month + interval, baseDate.day);
      }
    }

    // Fixed mode catch-up
    if (mode == 'fixed' && nextDate.compareTo(completionDate) <= 0) {
      while (nextDate.compareTo(completionDate) <= 0) {
        String nStr = calculateNextDueDate(
            rrule, mode, nextDate.toIso8601String().substring(0, 10), nextDate.toIso8601String().substring(0, 10));
        if (nStr == currentDueDateStr) break;
        nextDate = DateTime.parse(nStr);
      }
    }

    return nextDate.toIso8601String().substring(0, 10);
  }
}
