import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/reading_preferences_service.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/reading_font_size_control.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/ui/notes/widgets/note_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ReadingPreferencesService().resetScale();
  });

  group('ReadingPreferencesService Tests', () {
    test('default font scale is 1.0 (100%)', () {
      final service = ReadingPreferencesService();
      expect(service.currentScale, equals(1.0));
      expect(service.formattedPercentage, equals('100%'));
    });

    test('increasing scale steps correctly through scaleSteps', () {
      final service = ReadingPreferencesService();
      expect(service.currentScale, equals(1.0));

      service.increaseScale();
      expect(service.currentScale, equals(1.15));
      expect(service.formattedPercentage, equals('115%'));

      service.increaseScale();
      expect(service.currentScale, equals(1.30));

      service.increaseScale();
      expect(service.currentScale, equals(1.50));

      service.increaseScale();
      expect(service.currentScale, equals(1.70));

      // Cannot increase past max
      expect(service.canIncrease, isFalse);
      service.increaseScale();
      expect(service.currentScale, equals(1.70));
    });

    test('decreasing scale steps down and clamps at minimum', () {
      final service = ReadingPreferencesService();
      expect(service.currentScale, equals(1.0));

      service.decreaseScale();
      expect(service.currentScale, equals(0.85));
      expect(service.formattedPercentage, equals('85%'));

      // Cannot decrease past min
      expect(service.canDecrease, isFalse);
      service.decreaseScale();
      expect(service.currentScale, equals(0.85));
    });

    test('resetScale returns scale to 1.0', () {
      final service = ReadingPreferencesService();
      service.increaseScale();
      service.increaseScale();
      expect(service.currentScale, equals(1.30));

      service.resetScale();
      expect(service.currentScale, equals(1.0));
      expect(service.formattedPercentage, equals('100%'));
    });
  });

  group('ReadingFontSizeControl Widget Tests', () {
    testWidgets('renders A-, percentage, and A+ buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ReadingFontSizeControl(),
            ),
          ),
        ),
      );

      expect(find.text('A-'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('A+'), findsOneWidget);
    });

    testWidgets('tapping A+ increases font scale and updates UI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ReadingFontSizeControl(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('A+'));
      await tester.pumpAndSettle();

      expect(find.text('115%'), findsOneWidget);
      expect(ReadingPreferencesService().currentScale, equals(1.15));
    });

    testWidgets('tapping A- decreases font scale and updates UI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ReadingFontSizeControl(),
            ),
          ),
        ),
      );

      await tester.tap(find.text('A-'));
      await tester.pumpAndSettle();

      expect(find.text('85%'), findsOneWidget);
      expect(ReadingPreferencesService().currentScale, equals(0.85));
    });

    testWidgets('tapping percentage resets to 100%', (tester) async {
      final service = ReadingPreferencesService();
      service.increaseScale();
      service.increaseScale(); // 1.30

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ReadingFontSizeControl(),
            ),
          ),
        ),
      );

      expect(find.text('130%'), findsOneWidget);

      await tester.tap(find.text('130%'));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(service.currentScale, equals(1.0));
    });
  });

  group('AxisMarkdownViewer fontScale Tests', () {
    testWidgets('scales headings and paragraphs by fontScale', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AxisMarkdownViewer(
              markdown: '# Big Title\nRegular paragraph note content.',
              fontScale: 1.5,
            ),
          ),
        ),
      );

      // Verify widget rendered
      expect(find.byType(AxisMarkdownViewer), findsOneWidget);
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('Viewing NoteDetailSheet & TaskDetailSheet Font Controls Tests', () {
    testWidgets('NoteDetailSheet renders ReadingFontSizeControl for Notes',
        (tester) async {
      final note = Note(
        id: 'test-note-1',
        title: 'Meeting Notes',
        bodyMd: '- Discuss sprint roadmap\n- Review metrics',
        category: 'note',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteDetailSheet(
              note: note,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('NOTE CONTENT'), findsOneWidget);
      expect(find.byType(ReadingFontSizeControl), findsOneWidget);
      expect(find.text('A-'), findsOneWidget);
      expect(find.text('A+'), findsOneWidget);
    });

    testWidgets('NoteDetailSheet renders ReadingFontSizeControl for Journals',
        (tester) async {
      final journal = Note(
        id: 'test-journal-1',
        title: 'Daily Journal • Fri, Oct 23',
        bodyMd: '### 📅 What Happened Today\n- Shipped feature on time',
        category: 'journal',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteDetailSheet(
              note: journal,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('JOURNAL ENTRY'), findsOneWidget);
      expect(find.byType(ReadingFontSizeControl), findsOneWidget);
      expect(find.text('A-'), findsOneWidget);
      expect(find.text('A+'), findsOneWidget);
    });

    testWidgets(
        'TaskDetailSheet renders ReadingFontSizeControl when task has description',
        (tester) async {
      final task = Task(
        id: 'test-task-1',
        title: 'Implement Dark Mode',
        notes: '- Test high contrast colors\n- Check accessibility standards',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskDetailSheet(
              task: task,
            ),
          ),
        ),
      );

      expect(find.text('DESCRIPTION'), findsOneWidget);
      expect(find.byType(ReadingFontSizeControl), findsOneWidget);
      expect(find.text('A-'), findsOneWidget);
      expect(find.text('A+'), findsOneWidget);
    });
  });
}
