import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:axis/domain/update_checker.dart';

enum UpdateDownloadStatus {
  idle,
  checking,
  downloading,
  completed,
  failed,
}

class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    this.status = UpdateDownloadStatus.idle,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.percentage = 0.0,
    this.error,
    this.savedFilePath,
  });

  final UpdateDownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final double percentage; // 0.0 to 1.0
  final String? error;
  final String? savedFilePath;

  UpdateDownloadProgress copyWith({
    UpdateDownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    double? percentage,
    String? error,
    String? savedFilePath,
  }) {
    return UpdateDownloadProgress(
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      percentage: percentage ?? this.percentage,
      error: error,
      savedFilePath: savedFilePath ?? this.savedFilePath,
    );
  }
}

/// Central application update manager handling release detection, background download
/// with live stream progress telemetry, and native OS package installation.
class AppUpdateService {
  AppUpdateService._internal({
    http.Client? httpClient,
    this.githubRepo = 'YoussefAzzaz/Tasking',
  }) : _httpClient = httpClient ?? http.Client();

  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService({
    http.Client? httpClient,
    String githubRepo = 'YoussefAzzaz/Tasking',
  }) {
    if (httpClient != null) {
      return AppUpdateService._internal(
        httpClient: httpClient,
        githubRepo: githubRepo,
      );
    }
    return _instance;
  }

  final http.Client _httpClient;
  final String githubRepo;

  final ValueNotifier<UpdateInfo?> availableUpdateNotifier =
      ValueNotifier<UpdateInfo?>(null);
  final ValueNotifier<UpdateDownloadProgress> downloadProgressNotifier =
      ValueNotifier<UpdateDownloadProgress>(const UpdateDownloadProgress());
  final ValueNotifier<bool> isCheckingNotifier = ValueNotifier<bool>(false);

  String? _cachedCurrentVersion;
  int? _cachedCurrentBuildNumber;
  String? _dismissedVersion;

  String get currentPlatform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Retrieves the installed app version and build number.
  Future<SemanticVersion> getInstalledVersion() async {
    if (_cachedCurrentVersion != null && _cachedCurrentBuildNumber != null) {
      return SemanticVersion.parse(
        _cachedCurrentVersion!,
        _cachedCurrentBuildNumber,
      );
    }

    try {
      final info = await PackageInfo.fromPlatform();
      _cachedCurrentVersion = info.version;
      _cachedCurrentBuildNumber = int.tryParse(info.buildNumber) ?? 0;
      return SemanticVersion.parse(
        _cachedCurrentVersion!,
        _cachedCurrentBuildNumber,
      );
    } catch (_) {
      // Fallback to pubspec default if PackageInfo unavailable in testing
      _cachedCurrentVersion ??= '1.2.0';
      _cachedCurrentBuildNumber ??= 12;
      return SemanticVersion.parse(_cachedCurrentVersion!, _cachedCurrentBuildNumber);
    }
  }

  /// Sets mock version for unit testing or overrides.
  void setInstalledVersion(String version, int buildNumber) {
    _cachedCurrentVersion = version;
    _cachedCurrentBuildNumber = buildNumber;
  }

  /// Checks GitHub Releases for a newer version.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) async {
    if (isCheckingNotifier.value) return availableUpdateNotifier.value;
    isCheckingNotifier.value = true;

    try {
      final currentVer = await getInstalledVersion();
      final url = Uri.parse(
        'https://api.github.com/repos/$githubRepo/releases/latest',
      );

      final response = await _httpClient.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Axis-App-Updater',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[AppUpdateService] GitHub releases response: ${response.statusCode}');
        isCheckingNotifier.value = false;
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final update = UpdateInfo.fromGitHubRelease(
        json,
        targetPlatform: currentPlatform,
      );

      if (update == null) {
        isCheckingNotifier.value = false;
        return null;
      }

      final isNewer = update.isNewerThan(
        currentVer.toString(),
        currentVer.buildNumber,
      );

      if (isNewer) {
        availableUpdateNotifier.value = update;
        isCheckingNotifier.value = false;
        return update;
      } else {
        if (force) {
          availableUpdateNotifier.value = null;
        }
        isCheckingNotifier.value = false;
        return null;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for updates: $e');
      isCheckingNotifier.value = false;
      return null;
    }
  }

  /// Downloads the release file with real-time progress callbacks.
  Future<File?> downloadUpdate(
    UpdateInfo update, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    if (update.downloadUrl.isEmpty) {
      downloadProgressNotifier.value = const UpdateDownloadProgress(
        status: UpdateDownloadStatus.failed,
        error: 'No download URL available for this platform.',
      );
      return null;
    }

    try {
      final initialTotal = update.fileSizeBytes ?? 0;
      downloadProgressNotifier.value = UpdateDownloadProgress(
        status: UpdateDownloadStatus.downloading,
        receivedBytes: 0,
        totalBytes: initialTotal,
        percentage: 0.0,
      );

      String currentUrl = update.downloadUrl;
      http.StreamedResponse? response;

      // Follow redirects explicitly up to 5 times (GitHub releases redirect to S3 / Azure Blob)
      final client = _httpClient;
      for (int redirectCount = 0; redirectCount < 5; redirectCount++) {
        final request = http.Request('GET', Uri.parse(currentUrl));
        request.followRedirects = false;
        request.headers['User-Agent'] = 'Axis-App-Updater';
        request.headers['Accept'] = '*/*';

        final streamed = await client.send(request).timeout(const Duration(seconds: 25));
        if (streamed.statusCode == 301 ||
            streamed.statusCode == 302 ||
            streamed.statusCode == 303 ||
            streamed.statusCode == 307 ||
            streamed.statusCode == 308) {
          final location = streamed.headers['location'];
          await streamed.stream.drain();
          if (location != null && location.isNotEmpty) {
            currentUrl = Uri.parse(currentUrl).resolve(location).toString();
            continue;
          }
        }
        response = streamed;
        break;
      }

      if (response == null || response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Server returned HTTP ${response?.statusCode ?? "no response"}');
      }

      final totalBytes = (response.contentLength != null && response.contentLength! > 0)
          ? response.contentLength!
          : (update.fileSizeBytes ?? 0);
      int receivedBytes = 0;

      final cacheDir = await getTemporaryDirectory();
      final fileExtension = _resolveExtension(update.downloadUrl, currentPlatform);
      final filename = 'axis-update-v${update.version}$fileExtension';
      final saveFile = File(p.join(cacheDir.path, filename));

      // Overwrite if existing
      if (await saveFile.exists()) {
        await saveFile.delete();
      }

      final sink = saveFile.openWrite();

      downloadProgressNotifier.value = UpdateDownloadProgress(
        status: UpdateDownloadStatus.downloading,
        receivedBytes: 0,
        totalBytes: totalBytes,
        percentage: 0.0,
      );

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;

          final percent = totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;

          downloadProgressNotifier.value = UpdateDownloadProgress(
            status: UpdateDownloadStatus.downloading,
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            percentage: percent,
          );
          onProgress?.call(percent, receivedBytes, totalBytes);
        }

        await sink.flush();
      } finally {
        await sink.close();
      }

      downloadProgressNotifier.value = UpdateDownloadProgress(
        status: UpdateDownloadStatus.completed,
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
        percentage: 1.0,
        savedFilePath: saveFile.path,
      );

      return saveFile;
    } catch (e) {
      debugPrint('[AppUpdateService] Error downloading update: $e');
      downloadProgressNotifier.value = UpdateDownloadProgress(
        status: UpdateDownloadStatus.failed,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Triggers native OS installation of the downloaded update.
  Future<bool> installUpdate(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('[AppUpdateService] Cannot install: file not found at $filePath');
      return false;
    }

    try {
      if (Platform.isAndroid) {
        final result = await OpenFilex.open(
          filePath,
          type: 'application/vnd.android.package-archive',
        );
        debugPrint('[AppUpdateService] OpenFilex Android result: ${result.type} - ${result.message}');
        return result.type == ResultType.done;
      } else if (Platform.isLinux) {
        // On Linux, if it is a tarball or AppImage:
        if (filePath.endsWith('.AppImage')) {
          await Process.run('chmod', ['+x', filePath]);
          await Process.start(filePath, []);
          return true;
        } else {
          // Open directory or trigger default handler
          final result = await OpenFilex.open(filePath);
          return result.type == ResultType.done;
        }
      } else if (Platform.isWindows) {
        final result = await OpenFilex.open(filePath);
        return result.type == ResultType.done;
      } else {
        final result = await OpenFilex.open(filePath);
        return result.type == ResultType.done;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Error launching installer: $e');
      return false;
    }
  }

  /// Dismisses an optional update for the current session.
  void dismissUpdate(String version) {
    _dismissedVersion = version;
    if (availableUpdateNotifier.value?.version == version) {
      availableUpdateNotifier.value = null;
    }
  }

  bool isVersionDismissed(String version) => _dismissedVersion == version;

  String _resolveExtension(String url, String platform) {
    final urlPath = Uri.parse(url).path.toLowerCase();
    if (urlPath.endsWith('.apk')) return '.apk';
    if (urlPath.endsWith('.tar.gz')) return '.tar.gz';
    if (urlPath.endsWith('.appimage')) return '.AppImage';
    if (urlPath.endsWith('.deb')) return '.deb';
    if (urlPath.endsWith('.msix')) return '.msix';
    if (urlPath.endsWith('.exe')) return '.exe';
    if (urlPath.endsWith('.dmg')) return '.dmg';
    if (urlPath.endsWith('.zip')) return '.zip';

    switch (platform) {
      case 'android':
        return '.apk';
      case 'linux':
        return '.tar.gz';
      case 'windows':
        return '.msix';
      case 'macos':
        return '.dmg';
      default:
        return '.bin';
    }
  }
}
