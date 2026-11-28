class QuickAddResult {
  String title = '';
  int? priority;
  List<String> tags = [];
  String? project;
  String? dueDate;
  String? dueTime;
  int? estimate;
  String? recurrence;

  Map<String, dynamic> toJson() => {
    'title': title,
    'priority': priority,
    'tags': tags,
    'project': project,
    'due_date': dueDate,
    'due_time': dueTime,
    'estimate': estimate,
    'recurrence': recurrence,
  };

  /// Resolves relative 'today', 'tmr', or 'tomorrow' due dates to ISO 'YYYY-MM-DD' strings.
  String? resolveIsoDueDate([DateTime? referenceDate]) {
    if (dueDate == null) return null;
    final now = referenceDate ?? DateTime.now();
    if (dueDate == 'today') {
      return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    } else if (dueDate == 'tmr' || dueDate == 'tomorrow') {
      final tmr = DateTime(now.year, now.month, now.day + 1);
      return '${tmr.year.toString().padLeft(4, '0')}-${tmr.month.toString().padLeft(2, '0')}-${tmr.day.toString().padLeft(2, '0')}';
    }
    return dueDate;
  }
}

class QuickAddParser {
  static QuickAddResult parse(String text) {
    var result = QuickAddResult();
    var remaining = text;

    // 1. Priority (p1, p2, p3)
    var priorityMatch = RegExp(r'\b(p[1-3])\b', caseSensitive: false).firstMatch(remaining);
    if (priorityMatch != null) {
      result.priority = int.parse(priorityMatch.group(1)!.substring(1));
      remaining = remaining.replaceRange(priorityMatch.start, priorityMatch.end, ' ');
    }

    // 2. Project (#project)
    var projectMatch = RegExp(r'#(\w+)').firstMatch(remaining);
    if (projectMatch != null) {
      result.project = projectMatch.group(1);
      remaining = remaining.replaceRange(projectMatch.start, projectMatch.end, ' ');
    }

    // 3. Tags (@tag) - reversed to safely preserve match start/end indices
    var tagMatches = RegExp(r'@(\w+)').allMatches(remaining).toList();
    for (var match in tagMatches.reversed) {
      result.tags.add(match.group(1)!);
      remaining = remaining.replaceRange(match.start, match.end, ' ');
    }
    result.tags = result.tags.reversed.toList();

    // 4. Estimate (for 30m, 1h, 45m)
    var estimateMatch = RegExp(r'\bfor (\d+)(m|h)\b', caseSensitive: false).firstMatch(remaining) ?? 
                        RegExp(r'\b(\d+)(m|h)\b', caseSensitive: false).firstMatch(remaining);
    if (estimateMatch != null) {
      int val = int.parse(estimateMatch.group(1)!);
      result.estimate = estimateMatch.group(2)!.toLowerCase() == 'h' ? val * 60 : val;
      remaining = remaining.replaceRange(estimateMatch.start, estimateMatch.end, ' ');
    }

    // 5. Recurrence (every wednesday, every day, every 3 days ac, every week, every month, every 2 weeks)
    var weekdayRecMatch = RegExp(
      r'\bevery ((?:(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)(?:\s*,\s*|\s+and\s+)?)+)( ac)?\b',
      caseSensitive: false,
    ).firstMatch(remaining);
    if (weekdayRecMatch != null) {
      final rawDays = weekdayRecMatch.group(1)!.toLowerCase();
      const map = {
        'monday': 'MO',
        'mon': 'MO',
        'tuesday': 'TU',
        'tues': 'TU',
        'tue': 'TU',
        'wednesday': 'WE',
        'wed': 'WE',
        'thursday': 'TH',
        'thurs': 'TH',
        'thur': 'TH',
        'thu': 'TH',
        'friday': 'FR',
        'fri': 'FR',
        'saturday': 'SA',
        'sat': 'SA',
        'sunday': 'SU',
        'sun': 'SU',
      };
      final codes = <String>[];
      for (final token in rawDays.split(RegExp(r'(?:\s*,\s*|\s+and\s+|\s+)'))) {
        final code = map[token.trim()];
        if (code != null && !codes.contains(code)) {
          codes.add(code);
        }
      }
      if (codes.isNotEmpty) {
        final completionPart = (weekdayRecMatch.group(2) != null &&
                weekdayRecMatch.group(2)!.trim().isNotEmpty)
            ? ';COMPLETION=1'
            : '';
        result.recurrence = 'RRULE:FREQ=WEEKLY;BYDAY=${codes.join(',')}$completionPart';
        remaining = remaining.replaceRange(weekdayRecMatch.start, weekdayRecMatch.end, ' ');
      }
    }

    var recMatch = result.recurrence == null
        ? RegExp(
            r'\bevery (day|week|month|(\d+)\s*(days?|weeks?|months?))( ac)?\b',
            caseSensitive: false,
          ).firstMatch(remaining)
        : null;
    if (recMatch != null) {
      final unit = (recMatch.group(3) ?? recMatch.group(1) ?? 'day').toLowerCase();
      String freq = 'DAILY';
      if (unit.startsWith('week')) {
        freq = 'WEEKLY';
      } else if (unit.startsWith('month')) {
        freq = 'MONTHLY';
      }
      String intervalPart = '';
      if (recMatch.group(2) != null) {
        intervalPart = ';INTERVAL=${recMatch.group(2)}';
      }
      String completionPart = (recMatch.group(4) != null && recMatch.group(4)!.trim().isNotEmpty) ? ';COMPLETION=1' : '';
      result.recurrence = 'RRULE:FREQ=$freq$intervalPart$completionPart';
      remaining = remaining.replaceRange(recMatch.start, recMatch.end, ' ');
    }

    // 6. Time (at 8pm, at 14:30, at 5)
    var timeMatch = RegExp(r'\bat (\d{1,2}(:\d{2})?(am|pm)?)\b', caseSensitive: false).firstMatch(remaining) ?? 
                    RegExp(r'\b(\d{1,2}:\d{2})\b', caseSensitive: false).firstMatch(remaining);
    if (timeMatch != null) {
      String timeStr = timeMatch.group(1) ?? timeMatch.group(0)!;
      if (timeStr.toLowerCase().startsWith('at ')) {
        timeStr = timeStr.substring(3).trim();
      }
      bool isPm = timeStr.toLowerCase().endsWith('pm');
      bool isAm = timeStr.toLowerCase().endsWith('am');
      String cleanTime = timeStr.replaceAll(RegExp(r'[a-zA-Z]'), '').trim();
      List<String> parts = cleanTime.split(':');
      int? h = int.tryParse(parts[0]);
      int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      if (h != null) {
        if (isPm && h < 12) h += 12;
        if (isAm && h == 12) h = 0;
        if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          result.dueTime = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
          remaining = remaining.replaceRange(timeMatch.start, timeMatch.end, ' ');
        }
      }
    }

    // 7. Date (today, tmr, tomorrow, YYYY-MM-DD)
    var dateMatch = RegExp(r'\b(today|tomorrow|tmr|\d{4}-\d{2}-\d{2})\b', caseSensitive: false).firstMatch(remaining);
    if (dateMatch != null) {
      result.dueDate = dateMatch.group(0)!.toLowerCase();
      remaining = remaining.replaceRange(dateMatch.start, dateMatch.end, ' ');
    }

    // Cleanup whitespace
    result.title = remaining.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (result.dueTime != null && result.dueDate == null) {
      result.dueDate = 'today';
    }

    return result;
  }
}
