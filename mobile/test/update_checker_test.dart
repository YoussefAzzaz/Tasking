import 'package:flutter_test/flutter_test.dart';
import 'package:axis/domain/update_checker.dart';

void main() {
  group('SemanticVersion Unit Tests', () {
    test('parses standard version strings and formats correctly', () {
      final v1 = SemanticVersion.parse('1.2.0');
      expect(v1.major, 1);
      expect(v1.minor, 2);
      expect(v1.patch, 0);
      expect(v1.buildNumber, 0);
      expect(v1.toString(), '1.2.0');

      final v2 = SemanticVersion.parse('v1.2.1+13');
      expect(v2.major, 1);
      expect(v2.minor, 2);
      expect(v2.patch, 1);
      expect(v2.buildNumber, 13);
      expect(v2.toString(), '1.2.1+13');

      final v3 = SemanticVersion.parse('2.0.0-beta.1');
      expect(v3.major, 2);
      expect(v3.minor, 0);
      expect(v3.patch, 0);
      expect(v3.preRelease, 'beta.1');
    });

    test('compares semantic versions correctly across major, minor, patch, and buildNumber', () {
      final v100 = SemanticVersion.parse('1.0.0');
      final v110 = SemanticVersion.parse('1.1.0');
      final v111 = SemanticVersion.parse('1.1.1');
      final v200 = SemanticVersion.parse('2.0.0');

      expect(v110 > v100, isTrue);
      expect(v111 > v110, isTrue);
      expect(v200 > v111, isTrue);
      expect(v100 < v200, isTrue);
      expect(v100 == SemanticVersion.parse('1.0.0'), isTrue);

      // Build number comparison when major.minor.patch are equal
      final v120b12 = SemanticVersion.parse('1.2.0+12');
      final v120b13 = SemanticVersion.parse('1.2.0+13');
      expect(v120b13 > v120b12, isTrue);
      expect(v120b12 < v120b13, isTrue);
    });

    test('nextAxisReleaseVersion enforces 10-patch rollover rule and omits build in displayVersion', () {
      final v1210 = SemanticVersion.parse('1.2.10+24');
      expect(v1210.displayVersion, '1.2.10');

      final v130 = v1210.nextAxisReleaseVersion();
      expect(v130.displayVersion, '1.3.0');
      expect(v130.buildNumber, 25);

      var cur = v130;
      for (int p = 1; p <= 10; p++) {
        cur = cur.nextAxisReleaseVersion();
        expect(cur.minor, 3);
        expect(cur.patch, p);
      }
      expect(cur.displayVersion, '1.3.10');

      final v140 = cur.nextAxisReleaseVersion();
      expect(v140.displayVersion, '1.4.0');
    });
  });

  group('UpdateInfo Unit Tests', () {
    final update = UpdateInfo(
      version: '1.2.1',
      buildNumber: 13,
      releaseName: 'v1.2.1 Hotfix',
      releaseNotes: 'Fixed sync and added mobile calendar',
      publishedAt: DateTime(2026, 11, 16),
      downloadUrl: 'https://github.com/YoussefAzzaz/Tasking/releases/download/v1.2.1/app-release.apk',
      fileSizeBytes: 42000000,
      isMandatory: false,
    );

    test('isNewerThan returns true when current app version is older', () {
      expect(update.isNewerThan('1.2.0', 12), isTrue);
      expect(update.isNewerThan('1.2.1', 12), isTrue); // higher build number
      expect(update.isNewerThan('1.2.1', 13), isFalse); // same
      expect(update.isNewerThan('1.3.0', 1), isFalse); // current is newer
    });

    test('shouldPrompt respects dismissed versions unless mandatory', () {
      // Normal update: dismissed should not prompt
      expect(
        update.shouldPrompt(
          currentVersion: '1.2.0',
          currentBuildNumber: 12,
          dismissedVersion: '1.2.1',
        ),
        isFalse,
      );

      // Undismissed should prompt
      expect(
        update.shouldPrompt(
          currentVersion: '1.2.0',
          currentBuildNumber: 12,
          dismissedVersion: null,
        ),
        isTrue,
      );

      // Mandatory update always prompts even if dismissed
      final mandatoryUpdate = UpdateInfo(
        version: '1.2.1',
        buildNumber: 13,
        releaseName: 'Security Patch',
        releaseNotes: 'Critical security update',
        publishedAt: DateTime(2026, 11, 16),
        downloadUrl: 'https://example.com/update.apk',
        isMandatory: true,
      );

      expect(
        mandatoryUpdate.shouldPrompt(
          currentVersion: '1.2.0',
          currentBuildNumber: 12,
          dismissedVersion: '1.2.1',
        ),
        isTrue,
      );
    });

    test('fromGitHubRelease matches platform-specific assets', () {
      final sampleJson = {
        'tag_name': 'v1.2.1+13',
        'name': 'Axis Release v1.2.1',
        'body': 'Changelog: mobile calendar and auto-update\n\n[mandatory]',
        'published_at': '2026-11-16T10:00:00Z',
        'assets': [
          {
            'name': 'axis-v1.2.1-android.apk',
            'browser_download_url': 'https://github.com/releases/download/axis-v1.2.1-android.apk',
            'size': 35000000,
          },
          {
            'name': 'axis-v1.2.1-linux-x64.tar.gz',
            'browser_download_url': 'https://github.com/releases/download/axis-v1.2.1-linux-x64.tar.gz',
            'size': 45000000,
          },
          {
            'name': 'axis-v1.2.1-windows.msix',
            'browser_download_url': 'https://github.com/releases/download/axis-v1.2.1-windows.msix',
            'size': 50000000,
          },
        ],
      };

      final androidUpdate = UpdateInfo.fromGitHubRelease(sampleJson, targetPlatform: 'android');
      expect(androidUpdate, isNotNull);
      expect(androidUpdate!.version, '1.2.1');
      expect(androidUpdate.buildNumber, 13);
      expect(androidUpdate.downloadUrl, contains('axis-v1.2.1-android.apk'));
      expect(androidUpdate.isMandatory, isTrue); // parsed [mandatory]

      final linuxUpdate = UpdateInfo.fromGitHubRelease(sampleJson, targetPlatform: 'linux');
      expect(linuxUpdate, isNotNull);
      expect(linuxUpdate!.downloadUrl, contains('axis-v1.2.1-linux-x64.tar.gz'));

      final windowsUpdate = UpdateInfo.fromGitHubRelease(sampleJson, targetPlatform: 'windows');
      expect(windowsUpdate, isNotNull);
      expect(windowsUpdate!.downloadUrl, contains('axis-v1.2.1-windows.msix'));
    });
  });
}
