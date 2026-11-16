import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/notes/widgets/daily_journal_card.dart';

void main() {
  group('DailyJournalCard Widget Tests', () {
    testWidgets('DailyJournalCard renders properly on small mobile (320px) with start entry button', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool startTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DailyJournalCard(
                todayJournal: null,
                onOpenTodayJournal: (_) {},
                onStartNewJournal: () => startTriggered = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('DAILY JOURNAL'), findsOneWidget);
      expect(find.text('Start Today\'s Journal Entry'), findsOneWidget);

      await tester.tap(find.text('Start Today\'s Journal Entry'));
      await tester.pump();
      expect(startTriggered, isTrue);
    });

    testWidgets('Tapping mood pill triggers onStartNewJournalWithPrompt with selected mood', (tester) async {
      String? tappedMood;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DailyJournalCard(
              todayJournal: null,
              streak: 3,
              onOpenTodayJournal: (_) {},
              onStartNewJournal: () {},
              onStartNewJournalWithPrompt: ({initialMood, initialPrompt}) {
                tappedMood = initialMood;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('3d'), findsOneWidget);
      expect(find.text('High Energy'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);

      await tester.tap(find.text('High Energy'));
      await tester.pump();
      expect(tappedMood, 'HIGH ENERGY');
    });

    testWidgets('Renders logged journal with word count, metrics, and append action', (tester) async {
      final now = DateTime.now();
      final journal = Note(
        id: 'test_note_1',
        title: 'Morning Focus & Wins',
        bodyMd: 'Completed the major quarterly milestone with zero bugs reported.',
        category: 'journal',
        mood: 'CALM FOCUS',
        createdAt: now,
      );

      Note? appendedNote;
      Note? openedNote;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DailyJournalCard(
              todayJournal: journal,
              streak: 7,
              onOpenTodayJournal: (note) => openedNote = note,
              onAppendToTodayJournal: (note) => appendedNote = note,
              onStartNewJournal: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('7d'), findsOneWidget);
      expect(find.text('Morning Focus & Wins'), findsOneWidget);
      expect(find.text('CALM FOCUS'), findsOneWidget);
      expect(find.text('9 words'), findsOneWidget);
      expect(find.text('Log More Events'), findsOneWidget);
      expect(find.text('View Entry'), findsOneWidget);

      await tester.tap(find.text('Log More Events'));
      await tester.pump();
      expect(appendedNote?.id, 'test_note_1');

      await tester.tap(find.text('View Entry'));
      await tester.pump();
      expect(openedNote?.id, 'test_note_1');
    });
  });
}

