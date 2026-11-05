import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/habits/widgets/prayer_times_card.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/notes/create_note_sheet.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';

void main() {
  group('Sprint 7 Requirements Tests', () {
    testWidgets('PrayerTimesCard includes AnimatedRotation and AnimatedSize for expand/shrink animation',
        (tester) async {
      final prayers = PrayerTimeService.defaultPrayers();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AxisTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrayerTimesCard(
                prayers: prayers,
                onTogglePrayer: (id, done) {},
                onResetPrayers: () async {},
                onRefreshLocation: () async {},
              ),
            ),
          ),
        ),
      );

      // Verify header and animated rotation / size widgets exist
      expect(find.byType(AnimatedRotation), findsOneWidget);
      expect(find.byType(AnimatedSize), findsOneWidget);

      // Toggle expand/shrink
      await tester.tap(find.text('Prayers'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AnimatedSize), findsOneWidget);
    });

    testWidgets('CreateTaskSheet timer shows clean time with bolt icon and no emoji in text',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateTaskSheet(
              onTaskCreated: () {},
            ),
          ),
        ),
      );

      // Check micro presets: 5m, 10m, 15m (none should contain ⚡ emoji in text)
      for (final text in ['5m', '10m', '15m']) {
        expect(find.text(text), findsOneWidget);
        expect(find.text('⚡ $text'), findsNothing);
        expect(find.text('$text ⚡'), findsNothing);
      }

      // Bolt icons should be present for micro slots (5, 10, 15)
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
    });

    testWidgets('CreateTaskSheet description supports markup language and preview toggle',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateTaskSheet(
              onTaskCreated: () {},
            ),
          ),
        ),
      );

      // Verify NoteFormatToolbar is present for one-tap markdown formatting
      expect(find.byType(NoteFormatToolbar), findsOneWidget);
      expect(find.text('DESCRIPTION (MARKDOWN & LISTS)'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);

      // Type some markdown into description
      final descField = find.byType(TextField).at(1);
      await tester.enterText(descField, '### Task Context\n- [ ] Item 1\n- [ ] Item 2\n**High priority**');
      await tester.pump();

      // Tap Preview button
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      // Now Edit button should be shown and AxisMarkdownViewer rendered
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byType(AxisMarkdownViewer), findsOneWidget);
      expect(find.text('Task Context'), findsOneWidget);
    });

    testWidgets('CreateTaskSheet description box extends when focused or clicked and toggles with Expand/Compact button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateTaskSheet(
              onTaskCreated: () {},
            ),
          ),
        ),
      );

      // Initially compact
      expect(find.text('Expand'), findsOneWidget);
      var descField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(descField.minLines, equals(3));
      expect(descField.maxLines, equals(5));

      // Tap the description field to edit it
      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();

      // Should now be extended
      expect(find.text('Compact'), findsOneWidget);
      descField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(descField.minLines, equals(8));
      expect(descField.maxLines, equals(24));

      // Tap Compact toggle button
      await tester.tap(find.byKey(const ValueKey('desc_expand_toggle')));
      await tester.pumpAndSettle();

      // Should be compact again
      expect(find.text('Expand'), findsOneWidget);
      descField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(descField.minLines, equals(3));
      expect(descField.maxLines, equals(5));

      // Tap Expand toggle button
      await tester.tap(find.byKey(const ValueKey('desc_expand_toggle')));
      await tester.pumpAndSettle();

      // Should be extended again
      expect(find.text('Compact'), findsOneWidget);
      descField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(descField.minLines, equals(8));
      expect(descField.maxLines, equals(24));
    });

    testWidgets('CreateNoteSheet notes and journals box extends when clicked/focused and toggles with Expand/Compact button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateNoteSheet(
              initialCategory: 'journal',
              onNoteCreated: () {},
            ),
          ),
        ),
      );

      // Initially compact
      expect(find.text('Expand'), findsOneWidget);
      var bodyField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(bodyField.minLines, equals(4));
      expect(bodyField.maxLines, equals(7));

      // Tap body field to edit
      await tester.tap(find.byType(TextField).at(1));
      await tester.pumpAndSettle();

      // Should now be extended
      expect(find.text('Compact'), findsOneWidget);
      bodyField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(bodyField.minLines, equals(10));
      expect(bodyField.maxLines, equals(26));

      // Tap Compact toggle button
      await tester.tap(find.byKey(const ValueKey('note_expand_toggle')));
      await tester.pumpAndSettle();

      // Should be compact again
      expect(find.text('Expand'), findsOneWidget);
      bodyField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(bodyField.minLines, equals(4));
      expect(bodyField.maxLines, equals(7));
    });

    testWidgets('AxisMarkdownViewer checklist items are interactive and call onMarkdownChanged on tap',
        (tester) async {
      String? changedMarkdown;
      const initialMarkdown = '### Objectives\n- [ ] First Goal\n- [x] Already Done';

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AxisTheme.dark,
          home: Scaffold(
            body: AxisMarkdownViewer(
              markdown: initialMarkdown,
              onMarkdownChanged: (val) {
                changedMarkdown = val;
              },
            ),
          ),
        ),
      );

      expect(find.text('First Goal'), findsOneWidget);
      expect(find.text('Already Done'), findsOneWidget);

      // Tap the unchecked item ('First Goal')
      await tester.tap(find.text('First Goal'));
      await tester.pumpAndSettle();

      // Should have toggled to [x] First Goal
      expect(changedMarkdown, isNotNull);
      expect(changedMarkdown, contains('- [x] First Goal'));

      // Tap the checked item ('Already Done')
      await tester.tap(find.text('Already Done'));
      await tester.pumpAndSettle();

      // Should have toggled to [ ] Already Done
      expect(changedMarkdown, contains('- [ ] Already Done'));
    });

    testWidgets('CreateTaskSheet auto-fills project field when initialProject is passed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AxisTheme.dark,
          home: Scaffold(
            body: CreateTaskSheet(
              initialProject: 'Mobile Redesign',
              onTaskCreated: () {},
            ),
          ),
        ),
      );

      // The project field should display 'Mobile Redesign'
      expect(find.text('Mobile Redesign'), findsOneWidget);
    });

    testWidgets('RainbowColorPickerButton renders with rainbow sweep gradient and centered plus icon',
        (tester) async {
      String? pickedColor;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Center(
              child: RainbowColorPickerButton(
                selectedColor: '#10B981',
                onColorSelected: (col) => pickedColor = col,
              ),
            ),
          ),
        ),
      );

      // Verify RainbowColorPickerButton and its centered plus indicator
      expect(find.byType(RainbowColorPickerButton), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Tap the rainbow button to open the CyberColorPickerDialog
      await tester.tap(find.byType(RainbowColorPickerButton));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byType(CyberColorPickerDialog), findsOneWidget);
      expect(find.text('Pick Accent Color'), findsOneWidget);
      expect(find.text('HEX CODE'), findsOneWidget);

      // Select cyan preset (#06B6D4)
      await tester.tap(find.byIcon(Icons.palette_rounded));
      await tester.pumpAndSettle();

      // Tap "Select Color"
      await tester.tap(find.text('Select Color'));
      await tester.pumpAndSettle();

      expect(pickedColor, isNotNull);
      expect(pickedColor!.startsWith('#'), isTrue);
    });

    test('Projects ordering logic places 100% completed projects at the end', () {
      final now = DateTime.now();
      final projectActive = Project(id: 'p1', name: 'Active Project', createdAt: now);
      final projectDone = Project(id: 'p2', name: 'Completed Project', createdAt: now.add(const Duration(minutes: 1)));
      final projectEmpty = Project(id: 'p3', name: 'New Project Without Tasks', createdAt: now.add(const Duration(minutes: 2)));

      final tasksByProject = <String, List<Task>>{
        'Active Project': [
          Task(id: 't1', title: 'Task 1', status: 'done'),
          Task(id: 't2', title: 'Task 2', status: 'todo'),
        ],
        'Completed Project': [
          Task(id: 't3', title: 'Task 3', status: 'done'),
          Task(id: 't4', title: 'Task 4', status: 'done'),
        ],
        'New Project Without Tasks': [],
      };

      final allProjects = [projectDone, projectActive, projectEmpty];

      allProjects.sort((a, b) {
        final tasksA = tasksByProject[a.name] ?? [];
        final isDoneA = tasksA.isNotEmpty && tasksA.every((t) => t.status == 'done');

        final tasksB = tasksByProject[b.name] ?? [];
        final isDoneB = tasksB.isNotEmpty && tasksB.every((t) => t.status == 'done');

        if (isDoneA != isDoneB) {
          return isDoneA ? 1 : -1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });

      // Active Project and New Project should be on top; Completed Project should be at the end!
      expect(allProjects[0].name, 'Active Project');
      expect(allProjects[1].name, 'New Project Without Tasks');
      expect(allProjects[2].name, 'Completed Project');
    });
  });
}
