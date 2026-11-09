import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
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
  });
}

