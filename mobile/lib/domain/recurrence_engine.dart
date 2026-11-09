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
      if (kv.length == 2) rules[kv[0].toUpperCase()] = kv[1];
    }

    String freq = rules['FREQ'] ?? 'DAILY';
    int interval = int.tryParse(rules['INTERVAL'] ?? '1') ?? 1;
    if (interval < 1) interval = 1;

    DateTime baseDate = mode == 'after_completion' ? completionDate : currentDueDate;
    DateTime nextDate = _stepNextDate(baseDate, freq, interval, rules, currentDueDate.day);

    // Fixed mode catch-up: advance until nextDate > completionDate with max iteration guard
    if (mode == 'fixed' && nextDate.compareTo(completionDate) <= 0) {
      int iterations = 0;
      while (nextDate.compareTo(completionDate) <= 0 && iterations < 366) {
        iterations++;
        DateTime advanced = _stepNextDate(nextDate, freq, interval, rules, currentDueDate.day);
        if (advanced.compareTo(nextDate) <= 0) break; // Guard against non-advancing dates
        nextDate = advanced;
      }
    }

    final y = nextDate.year.toString().padLeft(4, '0');
    final m = nextDate.month.toString().padLeft(2, '0');
    final d = nextDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime _stepNextDate(
      DateTime fromDate, String freq, int interval, Map<String, String> rules, int originalDay) {
    if (freq == 'DAILY') {
      return DateTime(fromDate.year, fromDate.month, fromDate.day + interval);
    } else if (freq == 'WEEKLY') {
      if (rules.containsKey('BYDAY')) {
        var days = rules['BYDAY']!.split(',').map((d) => d.trim().toUpperCase());
        var dayMap = {
          'MO': DateTime.monday,
          'TU': DateTime.tuesday,
          'WE': DateTime.wednesday,
          'TH': DateTime.thursday,
          'FR': DateTime.friday,
          'SA': DateTime.saturday,
          'SU': DateTime.sunday,
        };

        var targetDays = days.map((d) => dayMap[d]).whereType<int>().toSet();

        for (int i = 1; i <= 7 * interval; i++) {
          var candidate = DateTime(fromDate.year, fromDate.month, fromDate.day + i);
          if (targetDays.contains(candidate.weekday)) {
            return candidate;
          }
        }
        return DateTime(fromDate.year, fromDate.month, fromDate.day + (7 * interval));
      } else {
        return DateTime(fromDate.year, fromDate.month, fromDate.day + (7 * interval));
      }
    } else if (freq == 'MONTHLY') {
      if (rules.containsKey('BYMONTHDAY')) {
        int targetDay = int.tryParse(rules['BYMONTHDAY']!) ?? originalDay;
        final nextMonth = DateTime(fromDate.year, fromDate.month + interval, 1);
        final daysInMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        return DateTime(nextMonth.year, nextMonth.month, targetDay > daysInMonth ? daysInMonth : targetDay);
      } else {
        final nextMonth = DateTime(fromDate.year, fromDate.month + interval, 1);
        final daysInMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        final targetDay = originalDay > daysInMonth ? daysInMonth : originalDay;
        return DateTime(nextMonth.year, nextMonth.month, targetDay);
      }
    }
    return DateTime(fromDate.year, fromDate.month, fromDate.day + interval);
  }
}
