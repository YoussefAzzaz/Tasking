import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/domain/quick_add_parser.dart';

void main() {
  test('QuickAddParser matches contract vectors', () {
    final file = File('../contract/quickadd.json');
    final jsonStr = file.readAsStringSync();
    final data = jsonDecode(jsonStr);

    final vectors = data['vectors'] as List<dynamic>;

    for (var vector in vectors) {
      final input = vector['input'] as String;
      final expected = vector['expected'] as Map<String, dynamic>;

      final parsed = QuickAddParser.parse(input);

      expect(parsed.title, expected['title'], reason: 'Title mismatch for "$input"');
      expect(parsed.priority, expected['priority'], reason: 'Priority mismatch for "$input"');
      expect(parsed.project, expected['project'], reason: 'Project mismatch for "$input"');
      expect(parsed.dueDate, expected['due_date'], reason: 'DueDate mismatch for "$input"');
      expect(parsed.dueTime, expected['due_time'], reason: 'DueTime mismatch for "$input"');
      expect(parsed.estimate, expected['estimate'], reason: 'Estimate mismatch for "$input"');
      expect(parsed.recurrence, expected['recurrence'], reason: 'Recurrence mismatch for "$input"');

      // Tags comparison
      final expectedTags = List<String>.from(expected['tags'] ?? [])..sort();
      final parsedTags = List<String>.from(parsed.tags)..sort();
      expect(parsedTags, expectedTags, reason: 'Tags mismatch for "$input"');
    }
  });

  test('QuickAddParser handles times without minutes (e.g. at 5)', () {
    final parsed = QuickAddParser.parse('Call mom at 5');
    expect(parsed.dueTime, '05:00');
    expect(parsed.title, 'Call mom');
  });

  test('QuickAddParser handles weekly, monthly recurrence and tomorrow keyword', () {
    final p1 = QuickAddParser.parse('Team sync every week');
    expect(p1.recurrence, 'RRULE:FREQ=WEEKLY');
    expect(p1.title, 'Team sync');

    final p2 = QuickAddParser.parse('Sprint planning every 2 weeks');
    expect(p2.recurrence, 'RRULE:FREQ=WEEKLY;INTERVAL=2');
    expect(p2.title, 'Sprint planning');

    final p3 = QuickAddParser.parse('Budget review every month');
    expect(p3.recurrence, 'RRULE:FREQ=MONTHLY');
    expect(p3.title, 'Budget review');

    final p4 = QuickAddParser.parse('Doctor appointment tomorrow at 10am');
    expect(p4.dueDate, 'tomorrow');
    expect(p4.dueTime, '10:00');
    expect(p4.title, 'Doctor appointment');
    final iso = p4.resolveIsoDueDate(DateTime(2026, 11, 8));
    expect(iso, '2026-11-09');
  });
}
