class RecurrenceEngine {
  static const List<int> orderedWeekdays = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  static const Map<String, int> _codeToDay = {
    'MO': DateTime.monday,
    'TU': DateTime.tuesday,
    'WE': DateTime.wednesday,
    'TH': DateTime.thursday,
    'FR': DateTime.friday,
    'SA': DateTime.saturday,
    'SU': DateTime.sunday,
  };

  static const Map<int, String> _dayToCode = {
    DateTime.monday: 'MO',
    DateTime.tuesday: 'TU',
    DateTime.wednesday: 'WE',
    DateTime.thursday: 'TH',
    DateTime.friday: 'FR',
    DateTime.saturday: 'SA',
    DateTime.sunday: 'SU',
  };

  static String? weekdayToCode(int weekday) => _dayToCode[weekday];

  static int? codeToWeekday(String code) => _codeToDay[code.trim().toUpperCase()];

  /// Builds a canonical weekly RRULE string (e.g. `RRULE:FREQ=WEEKLY;BYDAY=WE` or `MO,WE`).
  static String buildWeeklyRule(Iterable<int> weekdays, {int interval = 1}) {
    final normalized = weekdays
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();

    final intervalPart = interval > 1 ? ';INTERVAL=$interval' : '';
    if (normalized.isEmpty) {
      return 'RRULE:FREQ=WEEKLY$intervalPart';
    }
    final byDay = normalized.map((d) => _dayToCode[d]!).join(',');
    return 'RRULE:FREQ=WEEKLY$intervalPart;BYDAY=$byDay';
  }

  /// Returns true if [rrule] specifies a weekly recurrence rule.
  static bool isWeeklyRule(String? rrule) {
    if (rrule == null || rrule.trim().isEmpty) return false;
    final rules = _parseRules(rrule);
    return rules['FREQ']?.toUpperCase() == 'WEEKLY';
  }

  /// Extracts the set of Dart weekdays (`DateTime.monday..DateTime.sunday`) from a weekly [rrule].
  static Set<int> parseWeeklyDays(String? rrule, {DateTime? fallbackDate}) {
    if (rrule == null || rrule.trim().isEmpty) return <int>{};
    final rules = _parseRules(rrule);
    if (rules['FREQ']?.toUpperCase() != 'WEEKLY') return <int>{};

    final byDay = rules['BYDAY'];
    if (byDay != null && byDay.trim().isNotEmpty) {
      final parsed = byDay
          .split(',')
          .map((d) => _codeToDay[d.trim().toUpperCase()])
          .whereType<int>()
          .toSet();
      if (parsed.isNotEmpty) return parsed;
    }

    if (fallbackDate != null) {
      return {fallbackDate.weekday};
    }
    return <int>{};
  }

  /// Returns the earliest calendar date on or after [fromDate] (or strictly after
  /// when [includeFromDate] is false) whose weekday is in [weekdays].
  static DateTime nextMatchingWeekdayDate(
    DateTime fromDate,
    Set<int> weekdays, {
    bool includeFromDate = true,
  }) {
    final start = DateTime(fromDate.year, fromDate.month, fromDate.day);
    if (weekdays.isEmpty) return start;
    final startOffset = includeFromDate ? 0 : 1;
    for (int i = startOffset; i <= 7; i++) {
      final candidate = DateTime(start.year, start.month, start.day + i);
      if (weekdays.contains(candidate.weekday)) {
        return candidate;
      }
    }
    return start;
  }

  /// Determines whether a recurring task anchored on [anchorDateStr] (`YYYY-MM-DD`)
  /// occurs on [targetDateStr] (`YYYY-MM-DD`).
  static bool occursOnDate({
    required String? rrule,
    required String? anchorDateStr,
    required String targetDateStr,
  }) {
    if (anchorDateStr == null || anchorDateStr.trim().isEmpty) return false;
    final cleanAnchor = anchorDateStr.trim().split('T').first;
    final cleanTarget = targetDateStr.trim().split('T').first;
    if (cleanAnchor == cleanTarget) return true;

    if (rrule == null || !rrule.trim().toUpperCase().startsWith('RRULE:')) {
      return false;
    }

    final anchor = _parseUtcDate(cleanAnchor);
    final target = _parseUtcDate(cleanTarget);
    if (anchor == null || target == null) return false;
    if (target.isBefore(anchor)) return false;

    final rules = _parseRules(rrule);
    final freq = (rules['FREQ'] ?? 'DAILY').toUpperCase();
    var interval = int.tryParse(rules['INTERVAL'] ?? '1') ?? 1;
    if (interval < 1) interval = 1;

    final daysDiff = target.difference(anchor).inDays;
    if (daysDiff == 0) return true;

    if (freq == 'DAILY') {
      return daysDiff % interval == 0;
    } else if (freq == 'WEEKLY') {
      final byDayRaw = rules['BYDAY'];
      if (byDayRaw != null && byDayRaw.trim().isNotEmpty) {
        final targetDays = byDayRaw
            .split(',')
            .map((d) => _codeToDay[d.trim().toUpperCase()])
            .whereType<int>()
            .toSet();
        if (!targetDays.contains(target.weekday)) return false;
        if (interval == 1) return true;
        final anchorWeekMon = DateTime.utc(
          anchor.year,
          anchor.month,
          anchor.day - (anchor.weekday - 1),
        );
        final targetWeekMon = DateTime.utc(
          target.year,
          target.month,
          target.day - (target.weekday - 1),
        );
        final weeksDiff = targetWeekMon.difference(anchorWeekMon).inDays ~/ 7;
        return weeksDiff >= 0 && weeksDiff % interval == 0;
      } else {
        return daysDiff % (7 * interval) == 0;
      }
    } else if (freq == 'MONTHLY') {
      final monthsDiff =
          (target.year - anchor.year) * 12 + (target.month - anchor.month);
      if (monthsDiff <= 0 || monthsDiff % interval != 0) return false;
      final desiredDay = int.tryParse(rules['BYMONTHDAY'] ?? '') ?? anchor.day;
      final daysInTargetMonth =
          DateTime.utc(target.year, target.month + 1, 0).day;
      final clampedDay =
          desiredDay > daysInTargetMonth ? daysInTargetMonth : desiredDay;
      return target.day == clampedDay;
    }

    return false;
  }

  /// Resets completed markdown checklist items (`- [x]`) back to unchecked (`- [ ]`)
  /// when spawning the next occurrence of a recurring task.
  static String? uncheckMarkdownChecklists(String? notes) {
    if (notes == null || notes.isEmpty) return notes;
    return notes.replaceAllMapped(
      RegExp(r'^(\s*[-*]\s+)\[[xX]\]', multiLine: true),
      (m) => '${m.group(1)}[ ]',
    );
  }

  /// Formats an [rrule] into a concise human-readable label in English or Arabic.
  static String formatHumanReadable(String? rrule, {required bool isArabic}) {
    if (rrule == null || rrule.trim().isEmpty) return '';
    final rules = _parseRules(rrule);
    final freq = (rules['FREQ'] ?? '').toUpperCase();
    final interval = int.tryParse(rules['INTERVAL'] ?? '1') ?? 1;

    if (freq == 'WEEKLY') {
      final days = parseWeeklyDays(rrule).toList()..sort();
      if (days.length == 7) {
        return isArabic ? 'يومياً' : 'Every day';
      }
      if (days.isNotEmpty) {
        final dayLabels =
            days.map((d) => weekdayShortLabel(d, isArabic: isArabic)).join(isArabic ? '، ' : ', ');
        if (interval > 1) {
          return isArabic
              ? 'كل $interval أسابيع ($dayLabels)'
              : 'Every ${interval}w ($dayLabels)';
        }
        return isArabic ? 'كل $dayLabels' : 'Every $dayLabels';
      }
      if (interval > 1) {
        return isArabic ? 'كل $interval أسابيع' : 'Every $interval weeks';
      }
      return isArabic ? 'أسبوعياً' : 'Weekly';
    } else if (freq == 'DAILY') {
      if (interval > 1) {
        return isArabic ? 'كل $interval أيام' : 'Every $interval days';
      }
      return isArabic ? 'يومياً' : 'Daily';
    } else if (freq == 'MONTHLY') {
      if (interval > 1) {
        return isArabic ? 'كل $interval أشهر' : 'Every $interval months';
      }
      return isArabic ? 'شهرياً' : 'Monthly';
    }

    return rrule.replaceFirst(RegExp(r'^RRULE:', caseSensitive: false), '');
  }

  static String weekdayShortLabel(int weekday, {required bool isArabic}) {
    if (isArabic) {
      return const [
        'إثنين',
        'ثلاثاء',
        'أربعاء',
        'خميس',
        'جمعة',
        'سبت',
        'أحد',
      ][(weekday - 1).clamp(0, 6)];
    }
    return const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][(weekday - 1).clamp(0, 6)];
  }

  static String weekdayFullLabel(int weekday, {required bool isArabic}) {
    if (isArabic) {
      return const [
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ][(weekday - 1).clamp(0, 6)];
    }
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][(weekday - 1).clamp(0, 6)];
  }

  static Map<String, String> _parseRules(String rrule) {
    final trimmed = rrule.trim();
    final body = trimmed.toUpperCase().startsWith('RRULE:')
        ? trimmed.substring(6)
        : trimmed;
    final rules = <String, String>{};
    for (final p in body.split(';')) {
      final kv = p.split('=');
      if (kv.length == 2) {
        rules[kv[0].trim().toUpperCase()] = kv[1].trim().toUpperCase();
      }
    }
    return rules;
  }

  static DateTime? _parseUtcDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }

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
        var targetDays = days.map((d) => _codeToDay[d]).whereType<int>().toSet();

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
