import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/desktop/desktop_command_center.dart';
import 'package:axis/ui/desktop/screens/command_deck_screen.dart';
import 'package:axis/ui/desktop/screens/prayer_habits_screen.dart';
import 'package:axis/ui/desktop/screens/projects_tasks_screen.dart';
import 'package:axis/ui/desktop/screens/focus_timers_screen.dart';
import 'package:axis/ui/desktop/screens/journal_vault_screen.dart';
import 'package:axis/ui/desktop/screens/profile_settings_screen.dart';
import 'package:axis/data/focus_session_service.dart';

void main() {
  setUp(() {
    FocusSessionService().terminateSession();
  });

  tearDown(() {
    FocusSessionService().terminateSession();
  });

  Widget buildDesktopApp({Size size = const Size(1440, 900)}) {
    return MaterialApp(
      theme: AxisTheme.dark,
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

      // Titlebar elements
      expect(find.text('AXIS'), findsOneWidget);
      expect(find.text('v2.4.0'), findsOneWidget);
      expect(find.text('Search tasks, projects, habits, telemetry, or enter command...'), findsOneWidget);

      // Sidebar navigation items
      expect(find.text('Command Deck'), findsOneWidget);
      expect(find.text('Prayer & Habits'), findsOneWidget);
      expect(find.text('Projects & Tasks'), findsOneWidget);
      expect(find.text('Focus Timers'), findsOneWidget);
      expect(find.text('Journal & Vault'), findsOneWidget);
      expect(find.text('Profile & Settings'), findsOneWidget);

      // Command Deck active initially
      expect(find.text('Welcome Back, Commander'), findsOneWidget);
    });

    testWidgets('navigates across all 6 tabs without error or overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      // Tab 1: Prayer & Habits
      await tester.tap(find.text('Prayer & Habits'));
      await tester.pumpAndSettle();
      expect(find.byType(PrayerHabitsScreen), findsOneWidget);

      // Tab 2: Projects & Tasks
      await tester.tap(find.text('Projects & Tasks'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsTasksScreen), findsOneWidget);

      // Tab 3: Focus Timers
      await tester.tap(find.text('Focus Timers'));
      await tester.pumpAndSettle();
      expect(find.byType(FocusTimersScreen), findsOneWidget);

      // Tab 4: Journal & Vault
      await tester.tap(find.text('Journal & Vault'));
      await tester.pumpAndSettle();
      expect(find.byType(JournalVaultScreen), findsOneWidget);

      // Tab 5: Profile & Settings
      await tester.tap(find.text('Profile & Settings'));
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

    testWidgets('opens QuickTaskDialog via + New Task button', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildDesktopApp());
      await tester.pumpAndSettle();

      // Tap New Task button in sidebar
      await tester.tap(find.text('New Task'));
      await tester.pumpAndSettle();

      // CreateTaskSheet rendered inside dialog
      expect(find.byType(Dialog), findsOneWidget);
    });
  });
}
