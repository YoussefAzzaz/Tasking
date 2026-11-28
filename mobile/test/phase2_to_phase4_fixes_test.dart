import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/security/secure_credential_vault.dart';
import 'package:axis/core/storage/axis_storage.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/data/focus/focus_session_persistence.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/notifications/notification_ids.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/domain/auto_scheduler.dart';
import 'package:axis/ui/desktop/screens/focus_timers_screen.dart';
import 'package:axis/ui/focus/widgets/focus_dashboard_widgets.dart';
import 'package:axis/ui/friends/widgets/add_companion_sheet.dart';
import 'package:axis/ui/me/widgets/habit_categories_section.dart';
import 'package:axis/ui/me/widgets/note_categories_section.dart';
import 'package:axis/ui/me/widgets/task_tags_section.dart';
import 'package:axis/ui/me/widgets/user_profile_card.dart';

Widget _wrapWithL10n(Widget child, {Locale locale = const Locale('en'), ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AxisTheme.dark,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() {
    FocusSessionService().terminateSession();
    FocusSessionService().updateConfig(const FocusSessionConfig());
  });

  tearDown(() {
    FocusSessionService().terminateSession();
    FocusSessionService().updateConfig(const FocusSessionConfig());
  });

  group('Phase 2–4 Domain & Notification Regression Fixes', () {
    test('NotificationIds ranges are strictly disjoint across subsystems', () {
      final allIds = <int>{
        for (int order = 1; order <= 5; order++) NotificationIds.adhanForOrder(order),
        for (int order = 1; order <= 5; order++) NotificationIds.adhanNativeAlarmForOrder(order),
        NotificationIds.focusProgress,
        NotificationIds.focusCompleted,
        NotificationIds.adhanDebugTest,
        NotificationIds.keepAliveForeground,
        NotificationIds.keepAliveWakeup,
        NotificationIds.keepAliveRestart,
      };

      expect(allIds.length, 16);
      expect(NotificationIds.focusProgress, isNot(equals(NotificationIds.adhanForOrder(1))));
      expect(NotificationIds.focusCompleted, isNot(equals(NotificationIds.adhanForOrder(2))));
    });

    test('UserProfileRepository.formatFallbackFriendCode never emits hardcoded AX-7842', () {
      expect(UserProfileRepository.formatFallbackFriendCode(''), '---');
      expect(UserProfileRepository.formatFallbackFriendCode('local_guest'), '---');
      expect(UserProfileRepository.formatFallbackFriendCode('ab'), '---');
      expect(UserProfileRepository.formatFallbackFriendCode('f8e1-2345-6789'), 'AX-F8E1');
      expect(UserProfileRepository.formatFallbackFriendCode('f8e12345'), isNot('AX-7842'));
    });

    test('FocusYieldBreakdown keeps 25m baseline at 113 XP and scales dynamically', () {
      final standard = FocusYieldBreakdown.fromMinutes(25);
      expect(standard.baseXp, 75);
      expect(standard.boostXp, 38);
      expect(standard.totalXp, 113);

      final extended = FocusYieldBreakdown.fromMinutes(50);
      expect(extended.baseXp, 150);
      expect(extended.boostXp, 75);
      expect(extended.totalXp, 225);
    });

    test('FocusSessionPersistence.resolveSnapshot restores running, paused, and expired sessions', () {
      final baseTime = DateTime(2026, 11, 28, 12, 0, 0);

      final runningSnapshot = FocusSessionSnapshot(
        isRunning: true,
        isBreak: false,
        isSessionActive: true,
        completedCycles: 1,
        totalSeconds: 1500,
        remainingSeconds: 1200,
        targetEndTimeUtc: baseTime.add(const Duration(minutes: 10)).toUtc(),
        selectedSoundscape: 'Gentle Rain',
      );
      final running = FocusSessionPersistence.resolveSnapshot(runningSnapshot, now: baseTime);
      expect(running.shouldRestore, isTrue);
      expect(running.expiredWhileKilled, isFalse);
      expect(running.isRunning, isTrue);
      expect(running.remainingSeconds, 600);

      final expired = FocusSessionPersistence.resolveSnapshot(
        runningSnapshot,
        now: baseTime.add(const Duration(minutes: 12)),
      );
      expect(expired.shouldRestore, isTrue);
      expect(expired.expiredWhileKilled, isTrue);
      expect(expired.remainingSeconds, 0);

      const pausedSnapshot = FocusSessionSnapshot(
        isRunning: false,
        isBreak: true,
        isSessionActive: true,
        completedCycles: 2,
        totalSeconds: 300,
        remainingSeconds: 180,
        targetEndTimeUtc: null,
        selectedSoundscape: 'Forest Night',
      );
      final paused = FocusSessionPersistence.resolveSnapshot(pausedSnapshot, now: baseTime);
      expect(paused.shouldRestore, isTrue);
      expect(paused.isRunning, isFalse);
      expect(paused.isBreak, isTrue);
      expect(paused.remainingSeconds, 180);
    });

    test('AutoScheduler clamps nowTime only for localToday, not future/UTC-adjacent dates', () {
      final localNow = DateTime.now();
      final futureDate = localNow.add(const Duration(days: 2));
      final futureIso =
          '${futureDate.year.toString().padLeft(4, '0')}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}';
      final localTodayIso =
          '${localNow.year.toString().padLeft(4, '0')}-${localNow.month.toString().padLeft(2, '0')}-${localNow.day.toString().padLeft(2, '0')}';

      final futurePlan = AutoScheduler.schedule(
        futureIso,
        '18:00',
        '09:00',
        '20:00',
        0,
        30,
        const [],
        [SchedulableTask('t1', 30)],
      );
      expect(futurePlan.proposed.first.start, '09:00');

      final todayPlan = AutoScheduler.schedule(
        localTodayIso,
        '14:00',
        '09:00',
        '20:00',
        0,
        30,
        const [],
        [SchedulableTask('t1', 30)],
      );
      expect(todayPlan.proposed.first.start, '14:00');
    });

    test('Note.fromRow normalizes UTC timestamps to local DateTime', () {
      final note = Note.fromRow({
        'id': 'n1',
        'title': 'Evening Review',
        'body_md': 'Done',
        'created_at': '2026-11-28T23:30:00Z',
      });
      expect(note.createdAt.isUtc, isFalse);
    });

    test('AxisTheme.light text styles use dark readable foreground colors', () {
      final color = AxisTheme.light.textTheme.bodyLarge?.color;
      expect(color, isNotNull);
      expect(color!.computeLuminance(), lessThan(0.2));
    });
  });

  group('Phase 4 UI Widget Fixes', () {
    testWidgets('FocusTimersScreen & FocusYieldStrip reflect custom FocusSessionConfig', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FocusSessionService().updateConfig(const FocusSessionConfig(
        focusMinutes: 40,
        shortBreakMinutes: 10,
        longBreakMinutes: 20,
      ));

      await tester.pumpWidget(_wrapWithL10n(const FocusTimersScreen()));
      await tester.pumpAndSettle();
      expect(find.text('DURATION: 40m Sprint'), findsOneWidget);
      expect(find.text('DURATION: 25m Sprint'), findsNothing);

      FocusSessionService().startBreak();
      await tester.pumpAndSettle();
      expect(find.text('DURATION: 10m Break'), findsOneWidget);
      expect(find.text('DURATION: 5m Break'), findsNothing);

      await tester.pumpWidget(_wrapWithL10n(const FocusYieldStrip()));
      await tester.pumpAndSettle();
      expect(find.text('+120 Base'), findsOneWidget);
      expect(find.text('+60 Boost'), findsOneWidget);
      expect(find.text('180 XP'), findsOneWidget);
    });

    testWidgets('AddCompanionSheet displays --- and disables Copy when myFriendCode is empty', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(const AddCompanionSheet(myFriendCode: '')));
      await tester.pumpAndSettle();

      expect(find.text('---'), findsOneWidget);
      expect(find.text('AX-7842'), findsNothing);

      final copyButtons = tester.widgetList<ButtonStyleButton>(find.byType(ElevatedButton));
      expect(copyButtons.first.enabled, isFalse);
    });

    test('SecureCredentialVault uses per-install v2 keys with persistence and legacy decrypt compatibility', () async {
      final tempDir = await Directory.systemTemp.createTemp('axis_vault_test_');
      try {
        AxisStorage.resetForTesting();
        SecureCredentialVault.resetForTesting();
        AxisStorage.debugOverrideRootPath = tempDir.path;

        await SecureCredentialVault.init();
        final v2Cipher = SecureCredentialVault.encryptPassword('MySecret#2026');
        final v2Hash = SecureCredentialVault.hashPassword('MySecret#2026');
        expect(v2Cipher.startsWith('v2:'), isTrue);
        expect(v2Hash.length, 64);

        // Simulate app cold restart and confirm persisted device key restores access
        SecureCredentialVault.resetForTesting();
        await SecureCredentialVault.init();
        expect(SecureCredentialVault.decryptPassword(v2Cipher), 'MySecret#2026');
        expect(SecureCredentialVault.verifyPassword('MySecret#2026', v2Hash), isTrue);

        // Construct legacy v1 payload using the historical salt to verify upgrade compatibility
        const legacySalt = 'AXIS_OBSIDIAN_VAULT_2026_KINETIC_SALT';
        final legacyKey = Uint8List.fromList(
          sha256.convert(utf8.encode('AXIS_ENCRYPTION_KEY_SEED:$legacySalt')).bytes,
        );
        final iv = Uint8List.fromList(List<int>.generate(16, (i) => i + 1));
        final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
        cipher.init(true, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(legacyKey), iv), null));
        final encryptedBytes = cipher.process(Uint8List.fromList(utf8.encode('LegacyPass9!')));
        final legacyPayload = '${base64Encode(iv)}:${base64Encode(encryptedBytes)}';
        final legacyHash = sha256.convert(utf8.encode('LegacyPass9!:$legacySalt')).toString();

        expect(SecureCredentialVault.decryptPassword(legacyPayload), 'LegacyPass9!');
        expect(SecureCredentialVault.verifyPassword('LegacyPass9!', legacyHash), isTrue);
      } finally {
        SecureCredentialVault.resetForTesting();
        AxisStorage.resetForTesting();
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      }
    });

    test('AxisFonts and category/project reconciliation never depend on runtime HTTP or discovered_ prefixes', () {
      expect(AxisFonts.spaceGrotesk().fontFamily, 'SpaceGrotesk');
      expect(AxisFonts.getFont('Geist').fontFamily, 'Geist');
      expect(AxisFonts.jetBrainsMono().fontFamily, 'JetBrainsMono');
      expect(AxisFonts.spaceMono().fontFamily, 'SpaceMono');
      expect(AxisFonts.firaCode().fontFamily, 'FiraCode');

      final habitCat = HabitCategoryRepository.reconciledCategory('Deep Work');
      final noteCat = NoteCategoryRepository.reconciledCategory('Research');
      final proj = ProjectRepository.reconciledProject('Launch');
      expect(habitCat.id.startsWith('discovered_'), isFalse);
      expect(noteCat.id.startsWith('discovered_'), isFalse);
      expect(proj.id.startsWith('discovered_'), isFalse);
    });

    testWidgets('Me section create/edit dialogs cleanly dispose local controllers on close', (tester) async {
      await tester.pumpWidget(_wrapWithL10n(
        SingleChildScrollView(
          child: Column(
            children: [
              UserProfileCard(
                userName: 'Tester',
                userTitle: 'Specialist',
                level: 1,
                totalXp: 0,
                onSaveProfile: (String _, String _, [String? _]) {},
              ),
              HabitCategoriesSection(
                categories: const [],
                onAddCategory: (_, _) {},
                onDeleteCategory: (_, _) {},
              ),
              NoteCategoriesSection(
                categories: const [],
                onAddCategory: (_, _, _) {},
                onDeleteCategory: (_, _) {},
              ),
              TaskTagsSection(
                taskTags: const [],
                onAddTag: (_) {},
                onDeleteTag: (_) {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Category').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Category').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Tag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
