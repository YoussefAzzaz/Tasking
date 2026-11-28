import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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
  }) : _customHttpClient = httpClient;

  static final AppUpdateService _instance = AppUpdateService._internal();
  static const MethodChannel _updaterChannel = MethodChannel('com.axis.axis/updater');
  static bool _nativeHandlerRegistered = false;

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

  final http.Client? _customHttpClient;
  final String githubRepo;

  final ValueNotifier<UpdateInfo?> availableUpdateNotifier =
      ValueNotifier<UpdateInfo?>(null);
  final ValueNotifier<UpdateDownloadProgress> downloadProgressNotifier =
      ValueNotifier<UpdateDownloadProgress>(const UpdateDownloadProgress());
  final ValueNotifier<bool> isCheckingNotifier = ValueNotifier<bool>(false);

  static const Duration autoCheckCooldown = Duration(hours: 6);

  String? _cachedCurrentVersion;
  int? _cachedCurrentBuildNumber;
  String? _dismissedVersion;
  String? _lastAutoPromptedVersion;
  DateTime? _lastAutoCheckAt;
  String? lastErrorMessage;
  Future<UpdateInfo?>? _inFlightCheck;

  /// Cached semantic display version (e.g. `1.3.3`) if `getInstalledVersion` or
  /// `setInstalledVersion` has already run in this session.
  String? get cachedVersionLabel {
    if (_cachedCurrentVersion == null) return null;
    return SemanticVersion.parse(
      _cachedCurrentVersion!,
      _cachedCurrentBuildNumber,
    ).displayVersion;
  }

  /// Version string dismissed by the user in this session, if any.
  String? get dismissedVersion => _dismissedVersion;

  /// Whether an automatic background update check already succeeded recently.
  bool get isAutoCheckOnCooldown {
    final lastCheck = _lastAutoCheckAt;
    if (lastCheck == null) return false;
    return DateTime.now().difference(lastCheck) < autoCheckCooldown;
  }
  void Function(int receivedBytes, int totalBytes)? _nativeProgressCallback;

  bool get _usesCustomClient => _customHttpClient != null;
  bool get _useNativeAndroidHttp =>
      !_usesCustomClient && !kIsWeb && Platform.isAndroid;

  void _ensureNativeProgressHandler() {
    if (_nativeHandlerRegistered) return;
    try {
      _updaterChannel.setMethodCallHandler((call) async {
        if (call.method == 'onDownloadProgress') {
          final args = call.arguments;
          if (args is Map) {
            final received = (args['receivedBytes'] as num?)?.toInt() ?? 0;
            final total = (args['totalBytes'] as num?)?.toInt() ?? 0;
            _instance._nativeProgressCallback?.call(received, total);
          }
        }
      });
      _nativeHandlerRegistered = true;
    } catch (_) {
      // Safe fallback in pure Dart test environments without platform bindings
    }
  }

  http.Client _acquireClient() {
    if (_customHttpClient != null) return _customHttpClient;
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 5);
    return IOClient(ioClient);
  }

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
      _cachedCurrentVersion ??= '1.3.4';
      _cachedCurrentBuildNumber ??= 29;
      return SemanticVersion.parse(_cachedCurrentVersion!, _cachedCurrentBuildNumber);
    }
  }

  /// Sets mock version for unit testing or overrides.
  void setInstalledVersion(String version, int buildNumber) {
    _cachedCurrentVersion = version;
    _cachedCurrentBuildNumber = buildNumber;
  }

  /// Checks GitHub Releases for a newer version.
  Future<UpdateInfo?> checkForUpdate({bool force = false}) {
    final existing = _inFlightCheck;
    if (existing != null) {
      return existing;
    }
    final future = _performCheckForUpdate(force: force);
    _inFlightCheck = future;
    future.whenComplete(() {
      if (identical(_inFlightCheck, future)) {
        _inFlightCheck = null;
      }
    });
    return future;
  }

  Future<UpdateInfo?> _performCheckForUpdate({required bool force}) async {
    isCheckingNotifier.value = true;
    lastErrorMessage = null;

    try {
      final currentVer = await getInstalledVersion();
      final url = 'https://api.github.com/repos/$githubRepo/releases/latest';
      final payload = await _fetchReleaseJsonBody(url);

      if (payload == null) {
        return null;
      }
      _lastAutoCheckAt = DateTime.now();

      final json = jsonDecode(payload) as Map<String, dynamic>;
      final update = UpdateInfo.fromGitHubRelease(
        json,
        targetPlatform: currentPlatform,
      );

      if (update == null) {
        return null;
      }

      final isNewer = update.isNewerThan(
        currentVer.toString(),
        currentVer.buildNumber,
      );

      if (isNewer) {
        // Root-cause fix: non-forced checks (such as startup/resume checks) previously
        // re-assigned `availableUpdateNotifier.value` even after the user dismissed an
        // optional version, causing dismissed banners and modals to reappear on resume.
        final isDismissedOptional =
            !force && !update.isMandatory && isVersionDismissed(update.version);
        if (!isDismissedOptional) {
          availableUpdateNotifier.value = update;
        }
        return isDismissedOptional ? null : update;
      } else {
        if (force) {
          availableUpdateNotifier.value = null;
        }
        return null;
      }
    } catch (e) {
      lastErrorMessage = e.toString();
      debugPrint('[AppUpdateService] Error checking for updates: $e');
      return null;
    } finally {
      isCheckingNotifier.value = false;
    }
  }

  Future<String?> _fetchReleaseJsonBody(String urlStr) async {
    const headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'Axis-App-Updater',
      'Connection': 'close',
    };

    if (_useNativeAndroidHttp) {
      try {
        final res = await _updaterChannel
            .invokeMapMethod<String, dynamic>('fetchJson', {
              'url': urlStr,
              'headers': headers,
            })
            .timeout(const Duration(seconds: 35));
        if (res != null) {
          final statusCode = (res['statusCode'] as num?)?.toInt() ?? 0;
          if (statusCode != 200) {
            lastErrorMessage = 'HTTP $statusCode';
            debugPrint('[AppUpdateService] GitHub releases response: $statusCode');
            return null;
          }
          return res['body'] as String?;
        }
      } on MissingPluginException {
        // Fall back to Dart HTTP client when platform channel is absent (tests)
      } on PlatformException catch (e) {
        lastErrorMessage = e.message ?? 'Network error';
        debugPrint('[AppUpdateService] Native update check error: ${e.message}');
        return null;
      }
    }

    final client = _acquireClient();
    try {
      final response = await client
          .get(Uri.parse(urlStr), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        lastErrorMessage = 'HTTP ${response.statusCode}';
        debugPrint('[AppUpdateService] GitHub releases response: ${response.statusCode}');
        return null;
      }
      return response.body;
    } finally {
      if (!_usesCustomClient) {
        client.close();
      }
    }
  }

  /// Downloads the release file with real-time progress callbacks, stalled-stream
  /// recovery, trusted HTTPS host validation, and SHA-256 verification.
  Future<File?> downloadUpdate(
    UpdateInfo update, {
    void Function(double progress, int received, int total)? onProgress,
    Duration chunkTimeout = const Duration(seconds: 25),
  }) async {
    if (update.downloadUrl.isEmpty) {
      downloadProgressNotifier.value = const UpdateDownloadProgress(
        status: UpdateDownloadStatus.failed,
        error: 'No download URL available for this platform.',
      );
      return null;
    }

    if (!UpdateInfo.isTrustedReleaseUrl(update.downloadUrl)) {
      downloadProgressNotifier.value = const UpdateDownloadProgress(
        status: UpdateDownloadStatus.failed,
        error: 'Untrusted update download URL blocked for security.',
      );
      return null;
    }

    // Root cause: when no OS-specific binary asset is attached to a release yet,
    // UpdateInfo falls back to GitHub's release HTML tag page (`.../releases/tag/...`).
    // Downloading that HTML page would masquerade as an APK/tarball installer.
    final parsedUri = Uri.tryParse(update.downloadUrl);
    if (parsedUri != null && parsedUri.path.contains('/releases/tag/')) {
      downloadProgressNotifier.value = const UpdateDownloadProgress(
        status: UpdateDownloadStatus.failed,
        error:
            'No direct installer binary attached for this platform yet. Use Browser to open the release page.',
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

      final cacheDir = await getTemporaryDirectory();
      final fileExtension = _resolveExtension(update.downloadUrl, currentPlatform);
      final filename = 'axis-update-v${update.version}$fileExtension';
      final saveFile = File(p.join(cacheDir.path, filename));

      File downloadedFile;
      int finalReceivedBytes = 0;
      int finalTotalBytes = initialTotal;

      if (_useNativeAndroidHttp) {
        try {
          _ensureNativeProgressHandler();
          _nativeProgressCallback = (received, total) {
            final effectiveTotal = total > 0 ? total : initialTotal;
            final percent = effectiveTotal > 0
                ? (received / effectiveTotal).clamp(0.0, 1.0)
                : 0.0;
            downloadProgressNotifier.value = UpdateDownloadProgress(
              status: UpdateDownloadStatus.downloading,
              receivedBytes: received,
              totalBytes: effectiveTotal,
              percentage: percent,
            );
            onProgress?.call(percent, received, effectiveTotal);
          };

          final res = await _updaterChannel.invokeMapMethod<String, dynamic>(
            'downloadFile',
            {
              'url': update.downloadUrl,
              'destinationPath': saveFile.path,
              'expectedSize': initialTotal,
            },
          );
          _nativeProgressCallback = null;

          if (res != null) {
            finalReceivedBytes = (res['receivedBytes'] as num?)?.toInt() ?? 0;
            finalTotalBytes =
                (res['totalBytes'] as num?)?.toInt() ?? finalReceivedBytes;
            final outPath = res['path'] as String? ?? saveFile.path;
            downloadedFile = File(outPath);
            await _verifyDownloadedChecksum(downloadedFile, update);
            downloadProgressNotifier.value = UpdateDownloadProgress(
              status: UpdateDownloadStatus.completed,
              receivedBytes: finalReceivedBytes,
              totalBytes: finalTotalBytes,
              percentage: 1.0,
              savedFilePath: outPath,
            );
            return downloadedFile;
          }
        } on MissingPluginException {
          _nativeProgressCallback = null;
          // Fall back to Dart streaming download below
        } on PlatformException catch (e) {
          _nativeProgressCallback = null;
          throw Exception(e.message ?? 'Download failed over current network');
        }
      }

      downloadedFile = await _downloadWithDartHttp(
        update: update,
        saveFile: saveFile,
        onProgress: onProgress,
        chunkTimeout: chunkTimeout,
      );
      await _verifyDownloadedChecksum(downloadedFile, update);
      finalReceivedBytes = await downloadedFile.length();
      downloadProgressNotifier.value = UpdateDownloadProgress(
        status: UpdateDownloadStatus.completed,
        receivedBytes: finalReceivedBytes,
        totalBytes: initialTotal > 0 ? initialTotal : finalReceivedBytes,
        percentage: 1.0,
        savedFilePath: downloadedFile.path,
      );
      return downloadedFile;
    } catch (e) {
      debugPrint('[AppUpdateService] Error downloading update: $e');
      downloadProgressNotifier.value = UpdateDownloadProgress(
        status: UpdateDownloadStatus.failed,
        error: e.toString(),
      );
      return null;
    }
  }

  Future<void> _verifyDownloadedChecksum(File file, UpdateInfo update) async {
    String? expected = update.expectedSha256?.trim().toLowerCase();
    if ((expected == null || expected.isEmpty) &&
        update.sha256SumsUrl != null &&
        UpdateInfo.isTrustedReleaseUrl(update.sha256SumsUrl!)) {
      final sumsBody = await _fetchPlainTextBody(update.sha256SumsUrl!);
      if (sumsBody == null) {
        if (await file.exists()) await file.delete();
        throw Exception('Security verification failed: unable to fetch release checksums.');
      }
      final assetFileName =
          Uri.tryParse(update.downloadUrl)?.pathSegments.last ?? '';
      expected = UpdateInfo.parseSha256ForAsset(sumsBody, assetFileName);
      if (expected == null) {
        if (await file.exists()) await file.delete();
        throw Exception('Security verification failed: missing asset entry in SHA256SUMS.txt.');
      }
    }
    if (expected == null || expected.isEmpty) return;

    final bytes = await file.readAsBytes();
    final actual = sha256.convert(bytes).toString().toLowerCase();
    if (actual != expected) {
      if (await file.exists()) await file.delete();
      throw Exception('Security verification failed: downloaded package checksum mismatch.');
    }
  }

  Future<String?> _fetchPlainTextBody(String urlStr) async {
    const headers = <String, String>{
      'User-Agent': 'Axis-App-Updater',
      'Accept': 'text/plain, */*',
      'Connection': 'close',
    };
    if (_useNativeAndroidHttp) {
      try {
        final res = await _updaterChannel
            .invokeMapMethod<String, dynamic>('fetchJson', {
              'url': urlStr,
              'headers': headers,
            })
            .timeout(const Duration(seconds: 25));
        if (res != null && ((res['statusCode'] as num?)?.toInt() ?? 0) == 200) {
          return res['body'] as String?;
        }
      } on MissingPluginException {
        // Fall back to Dart HTTP client
      } on PlatformException {
        return null;
      }
    }
    final client = _acquireClient();
    try {
      final res = await client
          .get(Uri.parse(urlStr), headers: headers)
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200 ? res.body : null;
    } finally {
      if (!_usesCustomClient) client.close();
    }
  }

  Future<File> _downloadWithDartHttp({
    required UpdateInfo update,
    required File saveFile,
    void Function(double progress, int received, int total)? onProgress,
    required Duration chunkTimeout,
  }) async {
    final client = _acquireClient();
    try {
      String currentUrl = update.downloadUrl;
      http.StreamedResponse? response;

      // Follow redirects explicitly up to 8 times (GitHub releases redirect to release-assets / Azure)
      for (int redirectCount = 0; redirectCount < 8; redirectCount++) {
        final targetUri = Uri.parse(currentUrl);
        if (targetUri.scheme.toLowerCase() != 'https') {
          throw Exception('Blocked insecure non-HTTPS redirect target.');
        }
        final request = http.Request('GET', targetUri);
        request.followRedirects = false;
        request.headers['User-Agent'] = 'Axis-App-Updater';
        request.headers['Accept'] = '*/*';
        request.headers['Accept-Encoding'] = 'identity';
        request.headers['Connection'] = 'close';

        final streamed =
            await client.send(request).timeout(const Duration(seconds: 25));
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

      final totalBytes =
          (response.contentLength != null && response.contentLength! > 0)
              ? response.contentLength!
              : (update.fileSizeBytes ?? 0);
      int receivedBytes = 0;

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
        final timedStream = response.stream.timeout(
          chunkTimeout,
          onTimeout: (eventSink) {
            eventSink.addError(
              TimeoutException(
                'Download stalled on current network. Retry or use Browser.',
              ),
            );
            eventSink.close();
          },
        );

        await for (final chunk in timedStream) {
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

      if (receivedBytes <= 0) {
        throw Exception('Downloaded package is empty (0 bytes).');
      }
      if (response.contentLength != null &&
          response.contentLength! > 0 &&
          receivedBytes < response.contentLength!) {
        throw Exception(
          'Incomplete download ($receivedBytes / ${response.contentLength} bytes).',
        );
      }

      return saveFile;
    } finally {
      if (!_usesCustomClient) {
        client.close();
      }
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

  /// Returns true only when an automatic prompt should be shown for [update]
  /// in the current session (respecting dismissed versions and prior auto-prompts).
  bool shouldAutoPrompt(UpdateInfo update, SemanticVersion currentVer) {
    if (_lastAutoPromptedVersion == update.version) {
      return false;
    }
    return update.shouldPrompt(
      currentVersion: currentVer.toString(),
      currentBuildNumber: currentVer.buildNumber,
      dismissedVersion: _dismissedVersion,
    );
  }

  /// Marks [version] as already auto-prompted during this app session so
  /// resume lifecycle events never spam or re-stack dialogs.
  void markAutoPrompted(String version) {
    _lastAutoPromptedVersion = version;
  }

  @visibleForTesting
  void resetAutoPromptStateForTesting() {
    _dismissedVersion = null;
    _lastAutoPromptedVersion = null;
    _lastAutoCheckAt = null;
  }

  /// Dismisses an optional update for the current session.
  void dismissUpdate(String version) {
    _dismissedVersion = version;
    _lastAutoPromptedVersion = version;
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
