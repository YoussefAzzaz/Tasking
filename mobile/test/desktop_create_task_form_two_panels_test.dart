import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/desktop/dialogs/quick_task_dialog.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';

Widget _buildDesktopTestHost({
  required Widget child,
  Size size = const Size(1280, 800),
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AxisTheme.dark,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(size: size),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop CreateTaskSheet Two-Panel Layout Tests', () {
    testWidgets('renders into two panels: left for settings/options and right for description tools & box', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildDesktopTestHost(
          child: CreateTaskSheet(
            isDesktop: true,
            onTaskCreated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header without mobile grab handle
      expect(find.byType(TaskSheetHeader), findsOneWidget);
      expect(find.text('NEW TASK'), findsOneWidget);

      // Verify Two-Panel Split Layout
      expect(find.byType(VerticalDivider), findsOneWidget);

      // Left Panel: Settings and options
      expect(find.text('TASK NAME *'), findsOneWidget);
      expect(find.byType(TaskPrioritySelector), findsOneWidget);
      expect(find.text('P1 High'), findsOneWidget);
      expect(find.text('P2 Med'), findsOneWidget);
      expect(find.text('P3 Low'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.byType(TaskDatePickerRow), findsOneWidget);
      expect(find.byType(ProjectSelectorField), findsOneWidget);
      expect(find.byType(TagSelectorField), findsOneWidget);
      expect(find.byType(TaskSubmitButton), findsOneWidget);
      expect(find.text('CREATE TASK'), findsOneWidget);

      // Right Panel: Description tools with description box
      expect(find.text('DESCRIPTION (MARKDOWN & LISTS)'), findsOneWidget);
      expect(find.byType(NoteFormatToolbar), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);

      // Description TextField is present in the right panel
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);
    });

    testWidgets('right panel description tools and preview toggle function smoothly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildDesktopTestHost(
          child: CreateTaskSheet(
            isDesktop: true,
            onTaskCreated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter markdown text in description field
      // Find the description TextField (the expanded field inside the right panel)
      final descTextField = find.byWidgetPredicate(
        (w) => w is TextField && w.expands == true,
      );
      expect(descTextField, findsOneWidget);

      await tester.enterText(descTextField, '## Implementation Details\n- [ ] Step 1\n- [x] Step 2\n**Bold note**');
      await tester.pump();

      // Tap 'Preview' in the right panel
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      // In preview mode: Edit button is displayed, NoteFormatToolbar is hidden, AxisMarkdownViewer is displayed
      expect(find.text('Edit'), findsOneWidget);
      expect(find.byType(NoteFormatToolbar), findsNothing);
      expect(find.byType(AxisMarkdownViewer), findsOneWidget);
      expect(find.text('Implementation Details'), findsOneWidget);

      // Tap 'Edit' to return to editor
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Preview'), findsOneWidget);
      expect(find.byType(NoteFormatToolbar), findsOneWidget);
      expect(descTextField, findsOneWidget);
    });

    testWidgets('left panel settings interaction and validation work as expected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      bool taskCreatedCalled = false;

      await tester.pumpWidget(
        _buildDesktopTestHost(
          child: CreateTaskSheet(
            isDesktop: true,
            onTaskCreated: () {
              taskCreatedCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit with empty title -> displays validation error
      await tester.tap(find.byType(TaskSubmitButton));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a task name'), findsOneWidget);
      expect(taskCreatedCalled, isFalse);

      // Select Priority P2
      await tester.tap(find.text('P2 Med'));
      await tester.pumpAndSettle();

      // Enter task name in title field (the non-expanding TextField)
      final titleField = find.byWidgetPredicate(
        (w) => w is TextField && (w.expands != true),
      ).first;
      await tester.enterText(titleField, 'Two-panel desktop task test');
      await tester.pumpAndSettle();

      expect(find.text('Please enter a task name'), findsNothing);
    });

    testWidgets('QuickTaskDialog.show opens desktop task dialog in two panels', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => QuickTaskDialog.show(ctx),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // QuickTaskDialog dialog is open
      expect(find.byType(Dialog), findsOneWidget);
      // Two-panel layout elements are present
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.text('TASK NAME *'), findsOneWidget);
      expect(find.text('DESCRIPTION (MARKDOWN & LISTS)'), findsOneWidget);
      expect(find.byType(NoteFormatToolbar), findsOneWidget);

      // Close dialog via close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('Desktop two-panel task form supports Arabic RTL localization cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildDesktopTestHost(
          locale: const Locale('ar'),
          child: CreateTaskSheet(
            isDesktop: true,
            onTaskCreated: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Arabic labels
      expect(find.text('مهمة جديدة'), findsOneWidget);
      expect(find.text('اسم المهمة *'), findsOneWidget);
      expect(find.text('الوصف (ماركداون وقوائم)'), findsOneWidget);
      expect(find.text('معاينة'), findsOneWidget);
      expect(find.text('إنشاء مهمة'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);
    });
  });
}
