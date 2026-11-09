import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/ui/focus/focus_screen.dart';

void main() {
  setUp(() {
    FocusSessionService().terminateSession();
    FocusSessionService().updateConfig(const FocusSessionConfig(
      focusMinutes: 25,
      shortBreakMinutes: 5,
      longBreakMinutes: 15,
      cyclesBeforeLongBreak: 4,
      autoStartBreaks: false,
    ));
  });

  tearDown(() {
    FocusSessionService().terminateSession();
  });

  group('FocusSessionService Pomodoro Cycle Transitions', () {
    test('starts in focus mode and toggles to break correctly', () {
      final service = FocusSessionService();
      expect(service.isBreak, isFalse);
      expect(service.totalSeconds, equals(25 * 60));

      service.startBreak();
      expect(service.isBreak, isTrue);
      expect(service.totalSeconds, equals(5 * 60));

      service.startFocus();
      expect(service.isBreak, isFalse);
      expect(service.totalSeconds, equals(25 * 60));
    });

    test('completing a focus session transitions state to break and completes with XP', () async {
      final service = FocusSessionService();
      service.startFocus();
      expect(service.isBreak, isFalse);

      final events = <int>[];
      final sub = service.onSessionCompleted.listen(events.add);

      await service.completeSession();

      expect(events, contains(113));
      expect(service.isBreak, isTrue);
      expect(service.totalSeconds, equals(5 * 60));
      expect(service.completedCycles, equals(1));

      await sub.cancel();
    });

    test('completing a break session transitions state to focus with -1 event', () async {
      final service = FocusSessionService();
      service.startBreak();
      expect(service.isBreak, isTrue);

      final events = <int>[];
      final sub = service.onSessionCompleted.listen(events.add);

      await service.completeSession();

      expect(events, contains(-1));
      expect(service.isBreak, isFalse);
      expect(service.totalSeconds, equals(25 * 60));

      await sub.cancel();
    });
  });

  group('FocusScreen Pomodoro UI Dialog Transitions', () {
    testWidgets('shows Take Reboot Break dialog when focus completes', (tester) async {
      final service = FocusSessionService();
      service.resetTimer(minutes: 25, isBreak: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const FocusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await service.completeSession();
      await tester.pumpAndSettle();

      expect(find.text('Deep Session Complete!'), findsOneWidget);
      expect(find.text('Take Reboot Break'), findsOneWidget);

      await tester.tap(find.text('Take Reboot Break'));
      await tester.pump();

      expect(service.isBreak, isTrue);
      expect(service.totalSeconds, equals(5 * 60));

      service.pauseTimer();
      await tester.pumpAndSettle();
    });

    testWidgets('shows Launch Focus Session dialog when break completes and launches focus', (tester) async {
      final service = FocusSessionService();
      service.startBreak();
      expect(service.isBreak, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const FocusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('25m Normal Focus'), findsOneWidget);

      await service.completeSession();
      await tester.pumpAndSettle();

      expect(find.text('Reboot Break Complete!'), findsOneWidget);
      expect(find.text('Launch Focus Session'), findsOneWidget);
      expect(find.text('Deep Session Complete!'), findsNothing);
      expect(find.text('Take Reboot Break'), findsNothing);

      await tester.tap(find.text('Launch Focus Session'));
      await tester.pump();

      expect(service.isBreak, isFalse);
      expect(service.totalSeconds, equals(25 * 60));
      expect(service.isRunning, isTrue);

      service.pauseTimer();
      await tester.pumpAndSettle();
    });
  });
}
