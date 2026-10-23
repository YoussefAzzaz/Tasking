import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/core/router.dart';
import 'package:axis/ui/focus/focus_screen.dart';

void main() {
  setUp(() {
    FocusSessionService().resetTimer(minutes: 25);
  });

  tearDown(() {
    FocusSessionService().terminateSession();
  });

  group('NeuralSoundService Relaxing Sounds & Volume', () {
    test('normalizes legacy names to modern relaxing soundscapes', () {
      expect(
        NeuralSoundService.normalizeTrackName('Deep Theta 40Hz'),
        equals('Alpha Wave 10Hz'),
      );
      expect(
        NeuralSoundService.normalizeTrackName('Neon Rain'),
        equals('Gentle Rain'),
      );
      expect(
        NeuralSoundService.normalizeTrackName('Quantum Void'),
        equals('Deep Space'),
      );
      expect(
        NeuralSoundService.normalizeTrackName('Cyber Coffee'),
        equals('Campfire Glow'),
      );
      expect(
        NeuralSoundService.normalizeTrackName('Gentle Rain'),
        equals('Gentle Rain'),
      );
    });

    test('volume control sets and clamps volume', () async {
      final service = NeuralSoundService();
      await service.setVolume(0.85);
      expect(service.volume, equals(0.85));
      expect(service.volumeNotifier.value, equals(0.85));

      await service.setVolume(1.5);
      expect(service.volume, equals(1.0));

      await service.setVolume(-0.2);
      expect(service.volume, equals(0.0));
    });
  });

  group('SoundscapeSelectorGrid Component', () {
    testWidgets('filters soundscapes by category chip', (tester) async {
      String selected = 'Gentle Rain';
      final service = NeuralSoundService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SoundscapeSelectorGrid(
                selectedSoundscape: selected,
                soundService: service,
                onSelectSoundscape: (s) => selected = s,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Nature" category chip (first match)
      await tester.tap(find.text('Nature').first);
      await tester.pumpAndSettle();

      // Nature tracks are visible
      expect(find.text('Gentle Rain'), findsOneWidget);
      expect(find.text('Ocean Waves'), findsOneWidget);
      expect(find.text('Night Crickets'), findsOneWidget);

      // Ambient/Cozy tracks are filtered out
      expect(find.text('Campfire Glow'), findsNothing);
      expect(find.text('Deep Space'), findsNothing);

      // Tap "Cozy" category chip
      await tester.tap(find.text('Cozy').first);
      await tester.pumpAndSettle();
      expect(find.text('Campfire Glow'), findsOneWidget);
      expect(find.text('Gentle Rain'), findsNothing);
    });
  });

  group('FocusScreen Zen Fullscreen & Setup View', () {
    testWidgets('renders Setup View when session is not running', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const FocusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar in Setup View
      expect(find.text('DEEP WORK'), findsOneWidget);
      expect(find.text('TARGET OBJECTIVE'), findsOneWidget);
      expect(find.text('Yield:'), findsOneWidget);
      expect(find.text('ENGAGE DEEP SESSION'), findsOneWidget);
      expect(find.text('Relaxing Soundscapes'), findsOneWidget);
    });

    testWidgets('transitions to Zen Fullscreen mode with large Pomodoro timer on start', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const FocusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap ENGAGE DEEP SESSION to start focus cycle
      await tester.tap(find.text('ENGAGE DEEP SESSION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Zen Fullscreen mode takes over:
      // Distractions (Yield, DEEP WORK top bar, full soundscape rack) are hidden
      expect(find.text('Yield:'), findsNothing);
      expect(find.text('Relaxing Soundscapes'), findsNothing);

      // Zen Fullscreen elements are active:
      expect(find.byType(NeonTimerDial), findsOneWidget);
      expect(find.text('PAUSE DEEP SESSION'), findsOneWidget);
      expect(find.text('+5 Min Focus'), findsOneWidget);
      expect(find.text('AMBIENT SOUNDSCAPE'), findsOneWidget);

      // Tap +5 Min Focus adds 5 minutes
      await tester.tap(find.text('+5 Min Focus'));
      await tester.pump();
      expect(find.text('+5 Minutes Added to Focus Session'), findsOneWidget);

      // Tapping "View Setup & Stats" returns to setup dashboard
      await tester.tap(find.byTooltip('View Setup & Stats'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Yield:'), findsOneWidget);
      expect(find.text('Relaxing Soundscapes'), findsOneWidget);

      // Clean up timer
      FocusSessionService().pauseTimer();
      await tester.pumpAndSettle();
    });

    testWidgets('user can return to fullscreen session from setup view via multiple paths without pausing', (tester) async {
      tester.view.physicalSize = const Size(450, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: const FocusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Start session -> goes to Zen fullscreen
      await tester.tap(find.text('ENGAGE DEEP SESSION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('PAUSE DEEP SESSION'), findsOneWidget);

      // User clicks return arrow in session to check setup view
      await tester.tap(find.byTooltip('Minimize / Exit Focus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Now on Setup View while session is STILL RUNNING:
      // The top fullscreen icon and 'FOCUS SESSION IN PROGRESS' banner are removed as requested:
      expect(find.text('FOCUS SESSION IN PROGRESS'), findsNothing);
      expect(find.byTooltip('Return to Fullscreen Session'), findsNothing);

      // The primary button and pause button are present and clean:
      expect(find.textContaining('RETURN TO FULLSCREEN'), findsOneWidget);
      expect(find.text('PAUSE SESSION'), findsOneWidget);

      // Path 1: Tap "RETURN TO FULLSCREEN" button
      await tester.ensureVisible(find.textContaining('RETURN TO FULLSCREEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('RETURN TO FULLSCREEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Immediately back in Zen Fullscreen view without pausing!
      expect(find.text('PAUSE DEEP SESSION'), findsOneWidget);
      expect(FocusSessionService().isRunning, isTrue);

      // User clicks return arrow again
      await tester.tap(find.byTooltip('Minimize / Exit Focus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Path 2: Tap the NeonTimerDial itself
      await tester.tap(find.byType(NeonTimerDial));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Back in Zen Fullscreen view!
      expect(find.text('PAUSE DEEP SESSION'), findsOneWidget);
      expect(FocusSessionService().isRunning, isTrue);

      // Clean up
      FocusSessionService().pauseTimer();
      await tester.pumpAndSettle();
    });

    testWidgets('accesses task description sheet in focus session when target task is attached', (tester) async {
      final sampleTask = Task(
        id: 'task-focus-1',
        title: 'Architect Quantum Gateway',
        notes: '# Requirements\n- Zero latency\n- End-to-end encryption\n\nMust finish before sprint ends.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: FocusScreen(initialTask: sampleTask),
        ),
      );
      await tester.pumpAndSettle();

      // Start session -> Zen fullscreen
      await tester.tap(find.text('ENGAGE DEEP SESSION'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Target task title is displayed in Zen pill with description icon
      expect(find.text('Architect Quantum Gateway'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);

      // Tap pill to view task description
      await tester.tap(find.text('Architect Quantum Gateway'));
      await tester.pumpAndSettle();

      // Description sheet opens with full task details and markdown notes
      expect(find.text('TARGET OBJECTIVE'), findsOneWidget);
      expect(find.text('DESCRIPTION / NOTES'), findsOneWidget);
      expect(find.textContaining('Zero latency'), findsOneWidget);
      expect(find.textContaining('Must finish before sprint ends.'), findsOneWidget);

      // Dismiss description sheet
      await tester.tap(find.text('Back to Focus'));
      await tester.pumpAndSettle();

      // Timer is still running safely
      expect(FocusSessionService().isRunning, isTrue);
      expect(find.text('PAUSE DEEP SESSION'), findsOneWidget);

      // Clean up
      FocusSessionService().pauseTimer();
      await tester.pumpAndSettle();
    });

    testWidgets('FloatingFocusSessionBar renders when session is running and allows return', (tester) async {
      final sessionService = FocusSessionService();
      sessionService.resetTimer(minutes: 25);
      sessionService.setAttachedTask(Task(id: 't-1', title: 'Refactor Core Logic'));

      bool navigatedToFocus = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                const Text('Top Bar Header'),
                FloatingFocusSessionBar(
                  onTap: () => navigatedToFocus = true,
                ),
                const Expanded(child: Text('App Content Area')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // When timer is NOT running: floating bar is hidden
      expect(find.text('FOCUS ACTIVE'), findsNothing);

      // Start timer
      sessionService.startTimer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Floating bar is now visible under top bar with task title
      expect(find.text('FOCUS ACTIVE'), findsOneWidget);
      expect(find.text('Refactor Core Logic'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);

      // Tap floating bar
      await tester.tap(find.text('FOCUS ACTIVE'));
      await tester.pump();
      expect(navigatedToFocus, isTrue);

      // Clean up
      sessionService.pauseTimer();
      await tester.pumpAndSettle();
    });

    testWidgets('modal soundscape sheet updates selection UI immediately and has no bottom overflow', (tester) async {
      String selectedTrack = 'Gentle Rain';
      final soundService = NeuralSoundService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    SoundscapeSelectorGrid.showSoundscapeSheet(
                      context: ctx,
                      selectedSoundscape: selectedTrack,
                      soundService: soundService,
                      onSelectSoundscape: (val) => selectedTrack = val,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Check sheet opened with Relaxing Soundscapes header
      expect(find.text('Relaxing Soundscapes'), findsOneWidget);

      // Initially Gentle Rain has checkmark (Icons.check)
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap "Ocean Waves" to select it
      await tester.tap(find.text('Ocean Waves'));
      await tester.pumpAndSettle();

      // Selection state updated in caller callback
      expect(selectedTrack, equals('Ocean Waves'));

      // In the modal sheet UI, the checkmark is STILL visible and properly shifted to Ocean Waves
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Tap "Campfire Glow"
      await tester.tap(find.text('Campfire Glow'));
      await tester.pumpAndSettle();
      expect(selectedTrack, equals('Campfire Glow'));
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Verify no overflow occurred
      expect(tester.takeException(), isNull);
    });
  });
}
