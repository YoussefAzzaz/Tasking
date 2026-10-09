import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/domain/recurrence_engine.dart';
import 'package:axis/domain/auto_scheduler.dart';

void main() {
  test('RecurrenceEngine matches contract vectors', () {
    final file = File('../contract/recurrence.json');
    final data = jsonDecode(file.readAsStringSync());
    final vectors = data['vectors'] as List<dynamic>;

    for (var vector in vectors) {
      final nextDue = RecurrenceEngine.calculateNextDueDate(
        vector['rrule'],
        vector['mode'],
        vector['current_due_date'],
        vector['completion_date'],
      );
      expect(nextDue, vector['expected_next_due']);
    }
  });

  test('AutoScheduler matches contract vectors', () {
    final file = File('../contract/scheduler.json');
    final data = jsonDecode(file.readAsStringSync());
    final vectors = data['vectors'] as List<dynamic>;

    for (var vector in vectors) {
      final input = vector['input'];
      final expected = vector['expected'];

      List<BusyBlock> busy = (input['busy'] as List).map((b) {
        var startParts = b['start'].split(':');
        var endParts = b['end'].split(':');
        return BusyBlock(
            Duration(hours: int.parse(startParts[0]), minutes: int.parse(startParts[1])),
            Duration(hours: int.parse(endParts[0]), minutes: int.parse(endParts[1])));
      }).toList();

      List<SchedulableTask> tasks = (input['tasks'] as List).map((t) {
        return SchedulableTask(t['id'], t['estimate_min']);
      }).toList();

      final result = AutoScheduler.schedule(
        input['date'],
        input['now'],
        input['work_start'],
        input['work_end'],
        input['buffer_min'],
        input['default_estimate_min'],
        busy,
        tasks,
      );

      expect(result.availableMin, expected['available_min']);
      expect(result.plannedMin, expected['planned_min']);
      
      final expectedUnplaced = List<String>.from(expected['unplaced']);
      expect(result.unplaced, expectedUnplaced);

      final expectedProposed = expected['proposed'] as List;
      expect(result.proposed.length, expectedProposed.length);

      for (int i = 0; i < result.proposed.length; i++) {
        expect(result.proposed[i].id, expectedProposed[i]['id']);
        expect(result.proposed[i].start, expectedProposed[i]['start']);
        expect(result.proposed[i].end, expectedProposed[i]['end']);
      }
    }
  });
}
