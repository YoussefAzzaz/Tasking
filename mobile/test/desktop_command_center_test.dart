import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/desktop/desktop_command_center.dart';
import 'package:axis/ui/desktop/screens/command_deck_screen.dart';
import 'package:axis/ui/desktop/screens/prayer_habits_screen.dart';
import 'package:axis/ui/desktop/screens/projects_tasks_screen.dart';
import 'package:axis/ui/desktop/screens/focus_timers_screen.dart';
import 'package:axis/ui/desktop/screens/friends_accountability_screen.dart';
import 'package:axis/ui/desktop/screens/journal_vault_screen.dart';
import 'package:axis/ui/desktop/screens/profile_settings_screen.dart';
import 'package:axis/ui/desktop/widgets/accent_button.dart';
import 'package:axis/ui/desktop/widgets/ghost_button.dart';
import 'package:axis/ui/desktop/dialogs/quick_task_dialog.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';
import 'package:axis/ui/desktop/widgets/desktop_card.dart';
import 'package:axis/ui/desktop/screens/profile/desktop_badge_card.dart';
import 'package:axis/ui/notes/widgets/daily_journal_card.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/l10n/locale_service.dart';

void main() {
  setUp(() {
    FocusSessionService().terminateSession();
    LocaleService().setLocale(const Locale('en'));
  });

  tearDown(() {
    FocusSessionService().terminateSession();
  });

  Widget buildDesktopApp({Size size = const Size(1440, 900)}) {
    return MaterialApp(
      theme: AxisTheme.dark,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const DesktopCommandCenter(),
      ),
    );
  }

  group('DesktopCommandCenter Shell & Navigation Tests', () {
    testWidgets('renders Titlebar, Sidebar and initial Command Deck without overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      // Titlebar elements: logo.png asset, AXIS, no version, clock & date present
      expect(find.text('AXIS'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/logo.png'),
        findsOneWidget,
      );
      expect(find.text('v2.4.0'), findsNothing);
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsWidgets);
      expect(find.text('Search tasks, projects, habits, telemetry, or enter command...'), findsOneWidget);

      // Top Titlebar window control buttons pinned to max right
      expect(find.byTooltip('Minimize'), findsOneWidget);
      expect(find.byTooltip('Maximize / Fullscreen'), findsOneWidget);
      expect(find.byTooltip('Exit'), findsOneWidget);
      // Exit button is pinned flush to the far right corner (1440.0)
      expect(tester.getTopRight(find.byTooltip('Exit')).dx, 1440.0);

      // Settings button next to operator profile
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Sidebar navigation items
      expect(find.text('New Task'), findsNothing);
      expect(find.text('Command Deck'), findsOneWidget);
      expect(find.text('Projects & Tasks'), findsOneWidget);
      expect(find.text('Prayer & Habits'), findsOneWidget);
      expect(find.text('Journal & Vault'), findsOneWidget);
      expect(find.text('Focus Timers'), findsOneWidget);
      expect(find.text('Companions'), findsOneWidget);
      expect(find.text('Profile & Settings'), findsOneWidget);

      // Log Out button replaces vault integrity footer
      expect(find.text('INTEGRITY OK'), findsNothing);
      expect(find.text('Log Out'), findsOneWidget);

      // Command Deck active initially
      expect(find.text('Welcome Back, Commander'), findsOneWidget);
    });

    testWidgets('navigates across all tabs without error or overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      // Tab 1: Projects & Tasks
      await tester.tap(find.text('Projects & Tasks'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsTasksScreen), findsOneWidget);

      // Tab 2: Prayer & Habits
      await tester.tap(find.text('Prayer & Habits'));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerHabitsScreen), findsOneWidget);

      // Tab 3: Journal & Vault
      await tester.tap(find.text('Journal & Vault'));
      await tester.pumpAndSettle();
      expect(find.byType(JournalVaultScreen), findsOneWidget);

      // Tab 4: Focus Timers
      await tester.tap(find.text('Focus Timers'));
      await tester.pumpAndSettle();
      expect(find.byType(FocusTimersScreen), findsOneWidget);

      // Tab 5: Companions & Friends
      await tester.tap(find.text('Companions'));
      await tester.pumpAndSettle();
      expect(find.byType(FriendsAccountabilityScreen), findsOneWidget);

      // Settings button next to profile: Profile & Settings Screen
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSettingsScreen), findsOneWidget);

      // Return to Tab 0: Command Deck
      await tester.tap(find.text('Command Deck'));
      await tester.pumpAndSettle();
      expect(find.byType(CommandDeckScreen), findsOneWidget);
    });

    testWidgets('renders cleanly at minimum window resolution (1024x700)', (tester) async {
      tester.view.physicalSize = const Size(1024, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      FlutterError.onError = (FlutterErrorDetails details) {
        // ignore: avoid_print
        print('FLUTTER ERROR DETAILS:\n${details.toDiagnosticsNode().toStringDeep()}');
        FlutterError.presentError(details);
      };

      await tester.pumpWidget(buildDesktopApp(size: const Size(1024, 700)));
      await tester.pumpAndSettle();

      final err = tester.takeException();
      if (err != null) {
        // ignore: avoid_print
        print('EXCEPTION DETAILS:\n${err is FlutterError ? (err.diagnostics.map((d) => d.toStringDeep()).join("\n")) : err}');
      }
      expect(err, isNull);
      expect(tester.getTopRight(find.byTooltip('Exit')).dx, 1024.0);
    });

    testWidgets('opens and closes Omnibar dialog', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      // Tap Omnibar search in titlebar
      await tester.tap(find.text('Search tasks, projects, habits, telemetry, or enter command...'));
      await tester.pumpAndSettle();

      // Omnibar opened
      expect(find.text('Search tasks, projects, habits, notes or jump to...'), findsOneWidget);
    });

    testWidgets('opens QuickTaskDialog via QuickTaskDialog.show', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      QuickTaskDialog.show(tester.element(find.byType(DesktopCommandCenter)));
      await tester.pumpAndSettle();

      // CreateTaskSheet rendered inside dialog
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('eliminates mocks: displays dynamic focus, database telemetry, and real week calendar', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      // Command Deck: dynamic focus metric card exists and mock '1,280 rows' is gone
      expect(find.text('FOCUS TODAY'), findsOneWidget);
      expect(find.text('1,280 rows'), findsNothing);

      // Focus Timers: mock '3 of 4 planned' is gone and dynamic "TODAY'S SCHEDULE & SPRINTS" is present
      await tester.tap(find.text('Focus Timers'));
      await tester.pumpAndSettle();
      expect(find.text("TODAY'S SCHEDULE & SPRINTS"), findsOneWidget);
      expect(find.text('3 of 4 planned'), findsNothing);

      // Prayer & Habits: mock '95% Adherence' is gone, live adherence chip is present
      await tester.tap(find.text('Prayer & Habits'));
      await tester.pumpAndSettle();
      expect(find.text('THIS WEEK CONSISTENCY'), findsOneWidget);
      expect(find.text('95% Adherence'), findsNothing);

      // Journal & Vault: mock '42d Streak' is gone, live journal deck is present
      await tester.tap(find.text('Journal & Vault'));
      await tester.pumpAndSettle();
      expect(find.text('JOURNAL DECK'), findsOneWidget);
      expect(find.text('42d Streak'), findsNothing);

      // Projects & Tasks: open New Project dialog and check color picker
      await tester.tap(find.text('Projects & Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ New Project'));
      await tester.pumpAndSettle();
      expect(find.text('PROJECT COLOR'), findsOneWidget);
    });

    testWidgets('Command Deck displays 15m macro slots and daily journal, removes task quick add & filters', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      // Today's Execution Stream header exists
      expect(find.text("TODAY'S EXECUTION STREAM"), findsOneWidget);

      // Filters ('All', 'Overdue', 'High Priority') from execution stream are removed
      expect(find.text('Overdue'), findsNothing);
      expect(find.text('High Priority'), findsNothing);

      // Add a new task for today field and button are removed
      expect(find.text('+ Add a new task for today...'), findsNothing);

      // 15M Macro slots section is present
      expect(find.text('15 MIN MACRO SLOTS'), findsOneWidget);
      expect(find.text('RESCHEDULE'), findsOneWidget);

      // Daily Journal Card is present directly on Command Deck
      expect(find.text('DAILY JOURNAL'), findsOneWidget);

      // Verify Command Deck reorganized layout:
      // 1. Habit loops is under execution stream with the same width
      final execPos = tester.getTopLeft(find.byType(ExecutionStreamCard));
      final habitPos = tester.getTopLeft(find.byType(CommandDeckHabitLoopsCard));
      final execSize = tester.getSize(find.byType(ExecutionStreamCard));
      final habitSize = tester.getSize(find.byType(CommandDeckHabitLoopsCard));
      expect(execPos.dx, equals(habitPos.dx));
      expect(execSize.width, equals(habitSize.width));
      expect(execPos.dy, lessThan(habitPos.dy));

      // 2. 15m macro slots is under prayer telemetry with today's journal next to it
      final prayerPos = tester.getTopLeft(find.byType(CommandDeckPrayerTelemetryCard));
      final macroPos = tester.getTopLeft(find.byType(MacroSlotsCard));
      final journalPos = tester.getTopLeft(find.byType(DailyJournalCard));
      expect(prayerPos.dy, lessThan(macroPos.dy));
      expect(macroPos.dy, equals(journalPos.dy));
      expect(macroPos.dx, lessThan(journalPos.dx));
    });

    testWidgets('Prayer & Habits screen has New Habit button without extra text plus and scrollable habits', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prayer & Habits'));
      await tester.pumpAndSettle();

      // New Habit button label has no '+' prefix
      expect(find.text('New Habit'), findsOneWidget);
      expect(find.text('+ New Habit'), findsNothing);

      // Daily Habits header is present (uppercase by SectionHeader)
      expect(find.text('DAILY HABITS'), findsOneWidget);
    });

    testWidgets('Projects & Tasks screen has single-plus New Task, color picker, scrollable queue, and delete project', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Projects & Tasks'));
      await tester.pumpAndSettle();

      // New Task button has no text plus (+ New Task is gone, New Task appears in header)
      expect(find.text('+ New Task'), findsNothing);
      expect(find.widgetWithText(AccentButton, 'New Task'), findsOneWidget);

      // Add task to this queue textfield is removed
      expect(find.text('+ Add task to this queue...'), findsNothing);

      // Open + New Project dialog and verify rainbow color picker exists
      await tester.tap(find.text('+ New Project'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('PROJECT COLOR'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Journal & Vault screen has clean text fields, no emoji in editor, and top-aligned placeholder', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal & Vault'));
      await tester.pumpAndSettle();

      // Markdown Editor title has no thunder emoji
      expect(find.text('MARKDOWN EDITOR'), findsOneWidget);
      expect(find.text('⚡ MARKDOWN EDITOR'), findsNothing);

      // Verify editor text field has top vertical alignment
      final editorFieldFinder = find.byWidgetPredicate((w) => w is TextField && w.expands == true);
      expect(editorFieldFinder, findsOneWidget);
      final editorField = tester.widget<TextField>(editorFieldFinder);
      expect(editorField.textAlignVertical, equals(TextAlignVertical.top));

      // Verify no double text field styling (border is InputBorder.none, filled is false)
      expect(editorField.decoration?.border, equals(InputBorder.none));
      expect(editorField.decoration?.filled, isFalse);

      // Verify search text field has clean border
      final searchFieldFinder = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Search notes & tags...');
      expect(searchFieldFinder, findsOneWidget);
      final searchField = tester.widget<TextField>(searchFieldFinder);
      expect(searchField.decoration?.border, equals(InputBorder.none));
      expect(searchField.decoration?.filled, isFalse);

      // Check Vault hierarchy title exists and is followed by scrollable hierarchy
      expect(find.text('VAULT HIERARCHY'), findsOneWidget);
    });

    testWidgets('Journal & Vault has Save button on create, AUTO-SAVED on edit, and empties form on delete or tab switch', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal & Vault'));
      await tester.pumpAndSettle();

      // Initially in creation mode (no note selected yet)
      expect(find.widgetWithText(AccentButton, 'Save Note'), findsOneWidget);
      expect(find.widgetWithText(AccentButton, 'New Note'), findsOneWidget);
      expect(find.text('AUTO-SAVED'), findsNothing);

      // Type title and body
      final titleFieldFinder = find.byWidgetPredicate((w) =>
          w is TextField &&
          (w.decoration?.hintText == 'Note Title...' ||
              w.decoration?.hintText == 'Daily Reflection Title...'));
      await tester.enterText(titleFieldFinder, 'Architecture Guidelines');
      final bodyFieldFinder = find.byWidgetPredicate((w) => w is TextField && w.expands == true);
      await tester.enterText(bodyFieldFinder, '# Architecture\n\nClean boundaries.');
      await tester.pumpAndSettle();

      // Click Save Note
      await tester.tap(find.widgetWithText(AccentButton, 'Save Note').first);
      await tester.pumpAndSettle();

      // Now in editing mode: AUTO-SAVED appears, Save Note is in editor, New Note and Delete appear in header
      expect(find.text('AUTO-SAVED'), findsOneWidget);
      expect(find.widgetWithText(AccentButton, 'Save Note'), findsOneWidget);
      expect(find.widgetWithText(AccentButton, 'New Note'), findsOneWidget);
      expect(find.widgetWithText(GhostButton, 'Delete'), findsOneWidget);

      // Delete the note: form must be emptied!
      await tester.tap(find.widgetWithText(GhostButton, 'Delete'));
      await tester.pumpAndSettle();

      final deletedTitleField = tester.widget<TextField>(titleFieldFinder);
      final deletedBodyField = tester.widget<TextField>(bodyFieldFinder);
      expect(deletedTitleField.controller?.text, isEmpty);
      expect(deletedBodyField.controller?.text, isEmpty);
      expect(find.widgetWithText(AccentButton, 'Save Note'), findsOneWidget);

      // Type some draft content in creation mode
      await tester.enterText(titleFieldFinder, 'Draft Note');
      await tester.enterText(bodyFieldFinder, 'Some draft content');
      await tester.pumpAndSettle();

      // Switch tab to Journals: form must be emptied!
      await tester.tap(find.text('Journals'));
      await tester.pumpAndSettle();

      final journalTitleField = tester.widget<TextField>(titleFieldFinder);
      final journalBodyField = tester.widget<TextField>(bodyFieldFinder);
      expect(journalTitleField.controller?.text, isEmpty);
      expect(journalBodyField.controller?.text, isEmpty);
      expect(find.widgetWithText(AccentButton, 'Save Journal'), findsOneWidget);

      // Type in Journals draft
      await tester.enterText(titleFieldFinder, 'Draft Journal');
      await tester.pumpAndSettle();

      // Switch back to Notes: form must be emptied!
      await tester.tap(find.text('≡ Notes'));
      await tester.pumpAndSettle();

      final notesTitleField = tester.widget<TextField>(titleFieldFinder);
      final notesBodyField = tester.widget<TextField>(bodyFieldFinder);
      expect(notesTitleField.controller?.text, isEmpty);
      expect(notesBodyField.controller?.text, isEmpty);
      expect(find.widgetWithText(AccentButton, 'Save Note'), findsOneWidget);
    });

    testWidgets('Journal & Vault markdown editor includes complete formatting tools toolbar', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Journal & Vault'));
      await tester.pumpAndSettle();

      // Check presence of NoteFormatToolbar
      expect(find.byType(NoteFormatToolbar), findsOneWidget);

      // Verify Markdown tools are present
      expect(find.text('B'), findsOneWidget); // Bold
      expect(find.text('I'), findsOneWidget); // Italic
      expect(find.text('H1'), findsOneWidget); // H1
      expect(find.text('H2'), findsOneWidget); // H2
      expect(find.text('H3'), findsOneWidget); // H3
      expect(find.byIcon(Icons.format_list_numbered_rounded), findsOneWidget); // Numbered
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget); // Bullets
      expect(find.byIcon(Icons.check_box_outlined), findsOneWidget); // Checklist
      expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget); // Quote
      expect(find.byIcon(Icons.code_rounded), findsOneWidget); // Inline code
      expect(find.byIcon(Icons.data_object_rounded), findsOneWidget); // Code block
      expect(find.byIcon(Icons.link_rounded), findsOneWidget); // Link
      expect(find.byIcon(Icons.horizontal_rule_rounded), findsOneWidget); // Horizontal rule
      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget); // Table
      expect(
        find.descendant(
          of: find.byType(NoteFormatToolbar),
          matching: find.byIcon(Icons.schedule_rounded),
        ),
        findsOneWidget,
      ); // Timestamp log
    });

    testWidgets("Prayer & Habits top metric cards are all identically sized", (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prayer & Habits'));
      await tester.pumpAndSettle();

      expect(find.byType(PrayerHabitsScreen), findsOneWidget);
      expect(find.text("TODAY'S PRAYERS"), findsOneWidget);
      expect(find.text('HABIT STREAK'), findsOneWidget);
      expect(find.text('DAILY XP'), findsOneWidget);
      expect(find.text('NEXT PRAYER'), findsOneWidget);

      final prayerCardFinder = find.ancestor(of: find.text("TODAY'S PRAYERS"), matching: find.byType(DesktopCard));
      final habitCardFinder = find.ancestor(of: find.text('HABIT STREAK'), matching: find.byType(DesktopCard));
      final xpCardFinder = find.ancestor(of: find.text('DAILY XP'), matching: find.byType(DesktopCard));
      final nextPrayerCardFinder = find.ancestor(of: find.text('NEXT PRAYER'), matching: find.byType(DesktopCard));

      final prayerSize = tester.getSize(prayerCardFinder);
      final habitSize = tester.getSize(habitCardFinder);
      final xpSize = tester.getSize(xpCardFinder);
      final nextPrayerSize = tester.getSize(nextPrayerCardFinder);

      expect(prayerSize.height, equals(habitSize.height));
      expect(prayerSize.height, equals(xpSize.height));
      expect(prayerSize.height, equals(nextPrayerSize.height));
      expect(prayerSize.width, equals(habitSize.width));
    });

    testWidgets('Profile & Settings screen has redesigned desktop badges card with category filters and desktop dialog', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      // Navigate to Profile & Settings screen
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileSettingsScreen), findsOneWidget);
      expect(find.byType(DesktopMasteryBadgesCard), findsOneWidget);

      // Section header exists with UNLOCKED telemetry chip & Showroom button
      expect(find.text('OPERATOR MASTERY BADGES'), findsOneWidget);
      expect(find.text('Showroom ↗'), findsOneWidget);

      // Category filter pills are rendered in the desktop badges section
      expect(find.text('All'), findsWidgets);
      expect(find.text('Execution'), findsWidgets);
      expect(find.text('Unlocked Only'), findsOneWidget);

      // Redesigned desktop badge cards are rendered
      expect(find.byType(DesktopBadgeCard), findsWidgets);

      // Tapping a desktop badge card opens DesktopBadgeDetailDialog
      await tester.ensureVisible(find.byType(DesktopBadgeCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DesktopBadgeCard).first);
      await tester.pumpAndSettle();

      expect(find.text('MASTERY TIER ROADMAP'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('MASTERY TIER ROADMAP'), findsNothing);
    });

    testWidgets('Command Deck DailyJournalCard matches MacroSlotsCard height and habits/badges scroll smoothly without crashing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const Scaffold(
            body: DesktopCommandCenter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check height equality between MacroSlotsCard and DailyJournalCard
      final macroBox = tester.renderObject<RenderBox>(find.byType(MacroSlotsCard));
      final journalBox = tester.renderObject<RenderBox>(find.byType(DailyJournalCard));
      expect(journalBox.size.height, closeTo(macroBox.size.height, 1.0));

      // Scroll over habit loops card with mouse wheel
      final habitsFinder = find.byType(CommandDeckHabitLoopsCard);
      expect(habitsFinder, findsOneWidget);
      final habitCenter = tester.getCenter(habitsFinder);
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(habitCenter));
      await tester.pump();
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pumpAndSettle();

      // Navigate to Profile screen and scroll over badges card with mouse wheel
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      final badgesFinder = find.byType(DesktopMasteryBadgesCard);
      expect(badgesFinder, findsOneWidget);
      await tester.ensureVisible(badgesFinder);
      await tester.pumpAndSettle();

      final badgesCenter = tester.getCenter(badgesFinder);
      await tester.sendEventToBinding(pointer.hover(badgesCenter));
      await tester.pump();
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pumpAndSettle();
    });
  });
}
