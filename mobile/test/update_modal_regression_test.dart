import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/domain/update_checker.dart';
import 'package:axis/ui/common/updates/update_notice_banner.dart';
import 'package:axis/ui/common/updates/update_notice_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UpdateInfo makeTestUpdate({bool isMandatory = false}) => UpdateInfo(
        version: '1.4.0',
        buildNumber: 30,
        releaseName: 'Axis v1.4.0',
        releaseNotes: '- Fixed update notice stacking and version display',
        publishedAt: DateTime(2026, 11, 28),
        downloadUrl: 'https://github.com/example/axis/releases/download/v1.4.0/app-release.apk',
        fileSizeBytes: 24 * 1024 * 1024,
        isMandatory: isMandatory,
      );

  setUp(() {
    UpdateNoticeModal.resetModalStateForTesting();
  });

  tearDown(() {
    UpdateNoticeModal.resetModalStateForTesting();
  });

  group('UpdateNoticeModal Regression Tests', () {
    testWidgets(
      'displays actual installed version instead of 1.2.0 when currentVersion is omitted',
      (tester) async {
        final service = AppUpdateService(
          httpClient: MockClient((_) async => http.Response('{}', 404)),
        )..setInstalledVersion('1.3.3', 28);
        final update = makeTestUpdate();
        late BuildContext rootContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                rootContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        UpdateNoticeModal.show(
          rootContext,
          updateInfo: update,
          updateService: service,
        );
        await tester.pumpAndSettle();

        expect(find.byType(UpdateNoticeModal), findsOneWidget);
        expect(find.text('v1.3.3'), findsOneWidget);
        expect(find.text('v1.2.0'), findsNothing);
        expect(UpdateNoticeModal.isShowing, isTrue);

        await tester.tap(find.byKey(const ValueKey('update_modal_dismiss_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UpdateNoticeModal), findsNothing);
        expect(UpdateNoticeModal.isShowing, isFalse);
      },
    );

    testWidgets(
      'repeated or concurrent UpdateNoticeModal.show calls do not stack dialogs',
      (tester) async {
        final service = AppUpdateService(
          httpClient: MockClient((_) async => http.Response('{}', 404)),
        )..setInstalledVersion('1.3.3', 28);
        final update = makeTestUpdate();
        late BuildContext rootContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                rootContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );

        UpdateNoticeModal.show(
          rootContext,
          updateInfo: update,
          updateService: service,
        );
        UpdateNoticeModal.show(
          rootContext,
          updateInfo: update,
          updateService: service,
        );
        UpdateNoticeModal.show(
          rootContext,
          updateInfo: update,
          updateService: service,
        );
        await tester.pumpAndSettle();

        expect(find.byType(UpdateNoticeModal), findsOneWidget);
        expect(UpdateNoticeModal.isShowing, isTrue);

        await tester.tap(find.byKey(const ValueKey('update_modal_dismiss_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UpdateNoticeModal), findsNothing);
        expect(UpdateNoticeModal.isShowing, isFalse);

        // Verify dialog guard resets cleanly and allows a future explicit show.
        UpdateNoticeModal.show(
          rootContext,
          updateInfo: update,
          updateService: service,
        );
        await tester.pumpAndSettle();
        expect(find.byType(UpdateNoticeModal), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('update_modal_dismiss_button')));
        await tester.pumpAndSettle();
        expect(UpdateNoticeModal.isShowing, isFalse);
      },
    );

    testWidgets(
      'UpdateNoticeBanner opens modal with installed version and resists stacking',
      (tester) async {
        final service = AppUpdateService(
          httpClient: MockClient((_) async => http.Response('{}', 404)),
        )..setInstalledVersion('1.3.3', 28);
        final update = makeTestUpdate();
        service.availableUpdateNotifier.value = update;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdateNoticeBanner(updateService: service),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('update_banner_install_button')));
        await tester.pumpAndSettle();

        expect(find.byType(UpdateNoticeModal), findsOneWidget);
        expect(find.text('v1.3.3'), findsOneWidget);
        expect(find.text('v1.2.0'), findsNothing);

        final modalContext = tester.element(find.byType(UpdateNoticeModal));
        UpdateNoticeModal.show(
          modalContext,
          updateInfo: update,
          updateService: service,
        );
        await tester.pumpAndSettle();

        expect(find.byType(UpdateNoticeModal), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('update_modal_dismiss_button')));
        await tester.pumpAndSettle();
        expect(UpdateNoticeModal.isShowing, isFalse);
      },
    );
  });
}
