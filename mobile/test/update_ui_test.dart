import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/domain/update_checker.dart';
import 'package:axis/ui/common/updates/update_notice_modal.dart';
import 'package:axis/ui/common/updates/update_notice_banner.dart';
import 'package:axis/ui/me/widgets/me_update_section.dart';
import 'package:axis/ui/desktop/screens/profile/desktop_update_card.dart';

Widget _wrapWithApp(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AxisTheme.dark,
    home: Scaffold(body: child),
  );
}

void main() {
  final testUpdate = UpdateInfo(
    version: '1.3.0',
    buildNumber: 14,
    releaseName: 'Axis 1.3.0 - Performance & UI Release',
    releaseNotes: 'Added mobile calendar and automated over-the-air updates.',
    publishedAt: DateTime(2026, 11, 16),
    downloadUrl: 'https://github.com/mock/releases/download/v1.3.0/app-release.apk',
    fileSizeBytes: 35000000,
    isMandatory: false,
  );

  group('UpdateNoticeModal Widget Tests', () {
    testWidgets('renders version comparison, release notes, and action buttons', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          UpdateNoticeModal(
            updateInfo: testUpdate,
            currentVersion: '1.2.0',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SYSTEM UPDATE AVAILABLE'), findsOneWidget);
      expect(find.text('Axis 1.3.0 - Performance & UI Release'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.text('v1.3.0'), findsOneWidget);
      expect(find.text('Added mobile calendar and automated over-the-air updates.'), findsOneWidget);

      expect(find.byKey(const ValueKey('update_modal_download_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('update_modal_dismiss_button')), findsOneWidget);
    });

    testWidgets('displays live progress when download is in progress', (tester) async {
      final service = AppUpdateService();
      service.downloadProgressNotifier.value = const UpdateDownloadProgress(
        status: UpdateDownloadStatus.downloading,
        percentage: 0.65,
        receivedBytes: 22750000,
        totalBytes: 35000000,
      );

      await tester.pumpWidget(
        _wrapWithApp(
          UpdateNoticeModal(
            updateInfo: testUpdate,
            currentVersion: '1.2.0',
            updateService: service,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Downloading update package...'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays Install button when download is completed', (tester) async {
      final service = AppUpdateService();
      service.downloadProgressNotifier.value = const UpdateDownloadProgress(
        status: UpdateDownloadStatus.completed,
        percentage: 1.0,
        receivedBytes: 35000000,
        totalBytes: 35000000,
        savedFilePath: '/tmp/axis-update-v1.3.0.apk',
      );

      await tester.pumpWidget(
        _wrapWithApp(
          UpdateNoticeModal(
            updateInfo: testUpdate,
            currentVersion: '1.2.0',
            updateService: service,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('update_modal_install_button')), findsOneWidget);
      expect(find.text('Download complete! Tap Install to update.'), findsOneWidget);
    });

    testWidgets('displays Retry Update action when download fails', (tester) async {
      final service = AppUpdateService();
      service.downloadProgressNotifier.value = const UpdateDownloadProgress(
        status: UpdateDownloadStatus.failed,
        error: 'Download stalled on current network.',
      );

      await tester.pumpWidget(
        _wrapWithApp(
          UpdateNoticeModal(
            updateInfo: testUpdate,
            currentVersion: '1.3.0',
            updateService: service,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('update_modal_download_button')), findsOneWidget);
      expect(find.text('RETRY UPDATE'), findsOneWidget);
      expect(find.text('Download via browser directly'), findsOneWidget);
    });
  });

  group('UpdateNoticeBanner Widget Tests', () {
    testWidgets('renders nothing when no update is available', (tester) async {
      final service = AppUpdateService();
      service.availableUpdateNotifier.value = null;

      await tester.pumpWidget(
        _wrapWithApp(
          UpdateNoticeBanner(updateService: service),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('update_notice_banner')), findsNothing);
    });

    testWidgets('renders banner when update is available and allows dismissing', (tester) async {
      final service = AppUpdateService();
      service.availableUpdateNotifier.value = testUpdate;

      await tester.pumpWidget(
        _wrapWithApp(
          UpdateNoticeBanner(updateService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('update_notice_banner')), findsOneWidget);
      expect(find.textContaining('v1.3.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('update_banner_install_button')), findsOneWidget);

      // Dismiss
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(service.availableUpdateNotifier.value, isNull);
      expect(find.byKey(const ValueKey('update_notice_banner')), findsNothing);
    });
  });

  group('MeUpdateSection & DesktopUpdateCard Widget Tests', () {
    testWidgets('MeUpdateSection renders version and check button', (tester) async {
      final service = AppUpdateService();
      service.setInstalledVersion('1.2.0', 12);

      await tester.pumpWidget(
        _wrapWithApp(
          MeUpdateSection(updateService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SYSTEM VERSION & UPDATES'), findsOneWidget);
      expect(find.text('v1.2.0'), findsOneWidget);
      expect(find.textContaining('build.'), findsNothing);
      expect(find.byKey(const ValueKey('me_view_update_log_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('me_check_for_updates_button')), findsOneWidget);
    });

    testWidgets('DesktopUpdateCard renders desktop system version info and button', (tester) async {
      final service = AppUpdateService();
      service.setInstalledVersion('1.2.0', 12);

      await tester.pumpWidget(
        _wrapWithApp(
          DesktopUpdateCard(updateService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DESKTOP RELEASE & SYSTEM UPDATES'), findsOneWidget);
      expect(find.textContaining('1.2.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('desktop_check_for_updates_button')), findsOneWidget);
    });
  });
}
