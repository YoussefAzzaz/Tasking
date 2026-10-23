import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';
import 'package:axis/ui/notes/widgets/daily_journal_card.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';

void main() {
  group('AxisMarkdownViewer Markup Tests', () {
    testWidgets('renders ordered lists, bullet points, checklists, and headings', (tester) async {
      const markdown = '''
# Day Review
## Morning Events
### Objectives
1. Wake up and pray Fajr
2. Complete system architecture draft
- Water plants
* Review pull requests
• Prepare evening meal
- [ ] Workout session
- [x] Send daily summary
> "Focus on execution, not perfection."
`print('hello')`
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: AxisMarkdownViewer(markdown: markdown),
            ),
          ),
        ),
      );

      // Verify headings
      expect(find.text('Day Review'), findsOneWidget);
      expect(find.text('Morning Events'), findsOneWidget);
      expect(find.text('Objectives'), findsOneWidget);

      // Verify ordered list numbers and items
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Wake up and pray Fajr'), findsOneWidget);
      expect(find.text('Complete system architecture draft'), findsOneWidget);

      // Verify unordered list / bullet point items
      expect(find.text('Water plants'), findsOneWidget);
      expect(find.text('Review pull requests'), findsOneWidget);
      expect(find.text('Prepare evening meal'), findsOneWidget);

      // Verify checklist items
      expect(find.text('Workout session'), findsOneWidget);
      expect(find.text('Send daily summary'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Verify blockquote
      expect(find.text('"Focus on execution, not perfection."'), findsOneWidget);
    });
  });

  group('NoteFormatToolbar Tests', () {
    testWidgets('inserts ordered list, bullet, and bold formatting', (tester) async {
      final controller = TextEditingController(text: 'My task');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: NoteFormatToolbar(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );

      // Select all text
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 7);

      // Tap Bold button
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(controller.text, equals('**My task**'));

      // Test ordered list insertion at line start
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      await tester.tap(find.byIcon(Icons.format_list_numbered_rounded));
      await tester.pump();
      expect(controller.text.startsWith('1. '), isTrue);

      // Test bullet point insertion
      controller.text = 'Next item';
      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await tester.pump();
      expect(controller.text.startsWith('- '), isTrue);
    });
  });

  group('DailyJournalCard Tests', () {
    testWidgets('renders prompt to start journal when no entry exists for today', (tester) async {
      bool started = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DailyJournalCard(
              todayJournal: null,
              onOpenTodayJournal: (_) {},
              onStartNewJournal: () => started = true,
            ),
          ),
        ),
      );

      expect(find.text('DAILY JOURNAL'), findsOneWidget);
      expect(find.text('Log things that happened in your day'), findsOneWidget);
      expect(find.text('Start Today\'s Journal Entry'), findsOneWidget);

      await tester.tap(find.text('Start Today\'s Journal Entry'));
      await tester.pump();
      expect(started, isTrue);
    });

    testWidgets('renders today journal logged summary when entry exists', (tester) async {
      bool opened = false;
      final journal = Note(
        id: 'j1',
        title: 'Daily Journal • Today',
        bodyMd: '### 📅 What Happened Today\n- Met with team\n- Deployed feature',
        category: 'journal',
        mood: 'HIGH ENERGY',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: DailyJournalCard(
              todayJournal: journal,
              onOpenTodayJournal: (_) => opened = true,
              onStartNewJournal: () {},
            ),
          ),
        ),
      );

      expect(find.text("TODAY'S JOURNAL LOGGED"), findsOneWidget);
      expect(find.text('Daily Journal • Today'), findsOneWidget);
      expect(find.text('HIGH ENERGY'), findsOneWidget);
      expect(find.text('Log More Events'), findsOneWidget);

      await tester.tap(find.text('Log More Events'));
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('CreateNoteSheet inserts template and toggles markdown preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateNoteSheet(
              initialCategory: 'journal',
              onNoteCreated: () {},
            ),
          ),
        ),
      );

      // Verify template button is available for journal
      expect(find.text('Template'), findsOneWidget);
      await tester.tap(find.text('Template'));
      await tester.pump();

      // Verify template text inserted
      expect(find.textContaining('What Happened Today'), findsOneWidget);

      // Toggle Preview mode
      expect(find.text('Preview'), findsOneWidget);
      await tester.tap(find.text('Preview'));
      await tester.pump();

      // Verify AxisMarkdownViewer is active in preview mode
      expect(find.byType(AxisMarkdownViewer), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });
  });
}
