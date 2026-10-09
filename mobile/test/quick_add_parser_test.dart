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
}
