import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/domain/update_checker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService Tests', () {
    test('checkForUpdate detects newer version and emits update info', () async {
      final mockJson = jsonEncode({
        'tag_name': 'v1.3.0+14',
        'name': 'Axis 1.3.0 Release',
        'body': 'Major update with new features',
        'published_at': '2026-11-16T12:00:00Z',
        'assets': [
          {
            'name': 'axis-v1.3.0-android.apk',
            'browser_download_url': 'https://github.com/mock/axis-v1.3.0-android.apk',
            'size': 25000000,
          },
        ],
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/releases/latest')) {
          return http.Response(mockJson, 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = AppUpdateService(httpClient: mockClient);
      service.setInstalledVersion('1.2.0', 12);

      final update = await service.checkForUpdate();
      expect(update, isNotNull);
      expect(update!.version, '1.3.0');
      expect(service.availableUpdateNotifier.value, isNotNull);
      expect(service.availableUpdateNotifier.value!.version, '1.3.0');
    });

    test('checkForUpdate ignores if remote version is same or older', () async {
      final mockJson = jsonEncode({
        'tag_name': 'v1.2.0+12',
        'name': 'Axis 1.2.0 Release',
        'body': 'Current release',
        'published_at': '2026-11-16T12:00:00Z',
        'assets': [],
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200, headers: {'content-type': 'application/json'});
      });

      final service = AppUpdateService(httpClient: mockClient);
      service.setInstalledVersion('1.2.0', 12);

      final update = await service.checkForUpdate();
      expect(update, isNull);
    });

    test('dismissUpdate clears availableUpdateNotifier and flags version as dismissed', () async {
      final service = AppUpdateService();
      service.dismissUpdate('1.3.0');

      expect(service.isVersionDismissed('1.3.0'), isTrue);
      expect(service.isVersionDismissed('1.4.0'), isFalse);
    });

    test('checkForUpdate exposes lastErrorMessage on network failure and clears it on recovery', () async {
      var fail = true;
      final mockClient = MockClient((request) async {
        if (fail) {
          throw const SocketException('Wi-Fi timeout');
        }
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.3.1',
            'name': 'Axis 1.3.1',
            'body': 'Update',
            'published_at': '2026-11-24T12:00:00Z',
            'assets': [],
          }),
          200,
        );
      });

      final service = AppUpdateService(httpClient: mockClient);
      service.setInstalledVersion('1.3.0', 25);

      final failedResult = await service.checkForUpdate(force: true);
      expect(failedResult, isNull);
      expect(service.lastErrorMessage, isNotNull);

      fail = false;
      final okResult = await service.checkForUpdate(force: true);
      expect(okResult, isNotNull);
      expect(okResult!.version, '1.3.1');
      expect(service.lastErrorMessage, isNull);
    });

    test('downloadUpdate fails cleanly instead of hanging forever when stream stalls', () async {
      const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
        if (call.method == 'getTemporaryDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, null);
      });

      final controller = StreamController<List<int>>();
      addTearDown(controller.close);

      final stallingClient = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          controller.stream,
          200,
          contentLength: 1024 * 1024,
        );
      });

      final service = AppUpdateService(httpClient: stallingClient);
      final update = UpdateInfo(
        version: '1.3.1',
        buildNumber: 26,
        releaseName: 'Axis v1.3.1',
        releaseNotes: 'Test',
        publishedAt: DateTime(2026, 11, 24),
        downloadUrl: 'https://github.com/mock/axis-v1.3.1.apk',
        fileSizeBytes: 1024 * 1024,
      );

      final file = await service.downloadUpdate(
        update,
        chunkTimeout: const Duration(milliseconds: 50),
      );
      expect(file, isNull);
      expect(service.downloadProgressNotifier.value.status, UpdateDownloadStatus.failed);
      expect(service.downloadProgressNotifier.value.error, contains('stalled'));
    });
  });
}
