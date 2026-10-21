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
}

class QuickAddParser {
  static QuickAddResult parse(String text) {
    var result = QuickAddResult();
    var remaining = text;

    // 1. Priority
    var priorityMatch = RegExp(r'\b(p[1-3])\b', caseSensitive: false).firstMatch(remaining);
    if (priorityMatch != null) {
      result.priority = int.parse(priorityMatch.group(1)!.substring(1));
      remaining = remaining.replaceFirst(priorityMatch.group(0)!, '');
    }

    // 2. Project
    var projectMatch = RegExp(r'#(\w+)').firstMatch(remaining);
    if (projectMatch != null) {
      result.project = projectMatch.group(1);
      remaining = remaining.replaceFirst(projectMatch.group(0)!, '');
    }

    // 3. Tags
    var tagMatches = RegExp(r'@(\w+)').allMatches(remaining).toList();
    for (var match in tagMatches) {
      result.tags.add(match.group(1)!);
      remaining = remaining.replaceFirst(match.group(0)!, '');
    }

    // 4. Estimate
    var estimateMatch = RegExp(r'\bfor (\d+)(m|h)\b', caseSensitive: false).firstMatch(remaining) ?? 
                        RegExp(r'\b(\d+)(m|h)\b', caseSensitive: false).firstMatch(remaining);
    if (estimateMatch != null) {
      int val = int.parse(estimateMatch.group(1)!);
      result.estimate = estimateMatch.group(2)!.toLowerCase() == 'h' ? val * 60 : val;
      remaining = remaining.replaceFirst(estimateMatch.group(0)!, '');
    }

    // 5. Recurrence
    var recMatch = RegExp(r'\bevery (day|(\d+) days?)( ac)?\b', caseSensitive: false).firstMatch(remaining);
    if (recMatch != null) {
      String freq = 'DAILY';
      String intervalPart = '';
      if (recMatch.group(2) != null) {
        intervalPart = ';INTERVAL=${recMatch.group(2)}';
      }
      String completionPart = (recMatch.group(3) != null && recMatch.group(3)!.trim().isNotEmpty) ? ';COMPLETION=1' : '';
      result.recurrence = 'RRULE:FREQ=$freq$intervalPart$completionPart';
      remaining = remaining.replaceFirst(recMatch.group(0)!, '');
    }

    // 6. Time
    var timeMatch = RegExp(r'\bat (\d{1,2}(:\d{2})?(am|pm)?)\b', caseSensitive: false).firstMatch(remaining) ?? 
                    RegExp(r'\b(\d{1,2}:\d{2})\b', caseSensitive: false).firstMatch(remaining);
    if (timeMatch != null) {
      String timeStr = timeMatch.group(1)!;
      // Poor man's parse to HH:mm for simple times
      if (timeStr.toLowerCase().endsWith('pm') || timeStr.toLowerCase().endsWith('am')) {
        bool isPm = timeStr.toLowerCase().endsWith('pm');
        String t = timeStr.replaceAll(RegExp(r'[a-zA-Z]'), '');
        List<String> parts = t.split(':');
        int h = int.parse(parts[0]);
        int m = parts.length > 1 ? int.parse(parts[1]) : 0;
        if (isPm && h < 12) h += 12;
        if (!isPm && h == 12) h = 0;
        result.dueTime = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      } else {
        List<String> parts = timeStr.split(':');
        int h = int.parse(parts[0]);
        int m = parts.length > 1 ? int.parse(parts[1]) : 0;
        result.dueTime = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
      remaining = remaining.replaceFirst(timeMatch.group(0)!, '');
    }

    // 7. Date
    var dateMatch = RegExp(r'\b(today|tmr|\d{4}-\d{2}-\d{2})\b', caseSensitive: false).firstMatch(remaining);
    if (dateMatch != null) {
      result.dueDate = dateMatch.group(0)!.toLowerCase();
      remaining = remaining.replaceFirst(dateMatch.group(0)!, '');
    }

    // Cleanup
    result.title = remaining.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (result.dueTime != null && result.dueDate == null) {
      result.dueDate = 'today';
    }

    return result;
  }
}
