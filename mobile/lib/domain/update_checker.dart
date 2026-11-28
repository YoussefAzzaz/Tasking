/// Pure domain logic for semantic versioning, update evaluation, and release manifest parsing.
/// Zero UI, Zero DB, Zero network dependencies.
library;

class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber = 0,
    this.preRelease,
  });

  final int major;
  final int minor;
  final int patch;
  final int buildNumber;
  final String? preRelease;

  /// Parses strings like "1.2.0", "v1.2.1+13", "1.2.0-beta.1+42", "2.0".
  factory SemanticVersion.parse(String input, [int? fallbackBuildNumber]) {
    var raw = input.trim();
    if (raw.startsWith('v') || raw.startsWith('V')) {
      raw = raw.substring(1).trim();
    }

    int parsedBuild = fallbackBuildNumber ?? 0;
    if (raw.contains('+')) {
      final parts = raw.split('+');
      raw = parts[0].trim();
      final buildStr = parts.length > 1 ? parts[1].trim() : '';
      parsedBuild = int.tryParse(buildStr) ?? parsedBuild;
    }

    String? pre;
    if (raw.contains('-')) {
      final parts = raw.split('-');
      raw = parts[0].trim();
      pre = parts.length > 1 ? parts.sublist(1).join('-').trim() : null;
    }

    final segments = raw.split('.');
    final maj = segments.isNotEmpty ? (int.tryParse(segments[0]) ?? 0) : 0;
    final min = segments.length > 1 ? (int.tryParse(segments[1]) ?? 0) : 0;
    final pat = segments.length > 2 ? (int.tryParse(segments[2]) ?? 0) : 0;

    return SemanticVersion(
      major: maj,
      minor: min,
      patch: pat,
      buildNumber: parsedBuild,
      preRelease: pre,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (buildNumber != other.buildNumber) return buildNumber.compareTo(other.buildNumber);
    return 0;
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  /// User-facing version string without internal build number (e.g., `1.3.0`).
  String get displayVersion => '$major.$minor.$patch';

  /// Computes the next Axis release version using the 10-patch rollover cadence:
  /// keeps [minor] unchanged from `x.y.0` through `x.y.10`, then upgrades to
  /// `x.(y+1).0` after `x.y.10` (e.g., `1.2.10 -> 1.3.0`, `1.3.10 -> 1.4.0`).
  SemanticVersion nextAxisReleaseVersion() {
    final nextBuild = buildNumber > 0 ? buildNumber + 1 : 0;
    if (patch >= 10) {
      return SemanticVersion(
        major: major,
        minor: minor + 1,
        patch: 0,
        buildNumber: nextBuild,
      );
    }
    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch + 1,
      buildNumber: nextBuild,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemanticVersion &&
          runtimeType == other.runtimeType &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch &&
          buildNumber == other.buildNumber;

  @override
  int get hashCode =>
      major.hashCode ^ minor.hashCode ^ patch.hashCode ^ buildNumber.hashCode;

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    final withPre = preRelease != null ? '$base-$preRelease' : base;
    return buildNumber > 0 ? '$withPre+$buildNumber' : withPre;
  }
}

/// Metadata describing an available application release.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseName,
    required this.releaseNotes,
    required this.publishedAt,
    required this.downloadUrl,
    this.fileSizeBytes,
    this.isMandatory = false,
    this.platform = 'all',
    this.minSupportedVersion,
    this.sha256SumsUrl,
    this.expectedSha256,
  });

  final String version;
  final int buildNumber;
  final String releaseName;
  final String releaseNotes;
  final DateTime publishedAt;
  final String downloadUrl;
  final int? fileSizeBytes;
  final bool isMandatory;
  final String platform;
  final String? minSupportedVersion;
  final String? sha256SumsUrl;
  final String? expectedSha256;

  /// Verifies that an OTA release/manifest URL uses HTTPS and points to a
  /// trusted distribution domain (GitHub Releases / GitHub CDN / Supabase).
  static bool isTrustedReleaseUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      return false;
    }
    final host = uri.host.toLowerCase();
    return host == 'github.com' ||
        host.endsWith('.github.com') ||
        host == 'githubusercontent.com' ||
        host.endsWith('.githubusercontent.com') ||
        host.endsWith('.supabase.co');
  }

  /// Extracts a matching lowercase 64-char SHA-256 hex digest for [fileName]
  /// from the contents of a `SHA256SUMS.txt` release manifest.
  static String? parseSha256ForAsset(String sumsBody, String fileName) {
    final target = fileName.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final line in sumsBody.split('\n')) {
      final match = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$').firstMatch(line.trim());
      if (match == null) continue;
      final hash = match.group(1)!.toLowerCase();
      final candidate = match.group(2)!.trim().split('/').last.toLowerCase();
      if (candidate == target) {
        return hash;
      }
    }
    return null;
  }

  SemanticVersion get semver => SemanticVersion.parse(version, buildNumber);

  /// Checks if this update is newer than the provided current version and build number.
  bool isNewerThan(String currentVersion, [int? currentBuildNumber]) {
    final currentSemver = SemanticVersion.parse(currentVersion, currentBuildNumber);
    return semver > currentSemver;
  }

  /// Whether an update prompt should be shown to the user.
  bool shouldPrompt({
    required String currentVersion,
    int? currentBuildNumber,
    String? dismissedVersion,
  }) {
    if (!isNewerThan(currentVersion, currentBuildNumber)) return false;
    if (isMandatory) return true;
    if (dismissedVersion != null && dismissedVersion.trim() == version.trim()) {
      return false;
    }
    return true;
  }

  /// Parses a GitHub Release JSON object into an [UpdateInfo] for the requested platform.
  static UpdateInfo? fromGitHubRelease(
    Map<String, dynamic> json, {
    required String targetPlatform,
  }) {
    final tagName = json['tag_name'] as String? ?? '';
    if (tagName.isEmpty) return null;

    final name = json['name'] as String? ?? tagName;
    final body = json['body'] as String? ?? '';
    final publishedStr = json['published_at'] as String?;
    final publishedAt = publishedStr != null
        ? DateTime.tryParse(publishedStr) ?? DateTime.now()
        : DateTime.now();

    final semver = SemanticVersion.parse(tagName);
    int remoteBuildNumber = semver.buildNumber;
    if (remoteBuildNumber == 0) {
      final buildMatch = RegExp(r'\+(\d+)').firstMatch('$name $tagName $body');
      if (buildMatch != null) {
        remoteBuildNumber = int.tryParse(buildMatch.group(1)!) ?? 0;
      }
    }
    final assets = (json['assets'] as List<dynamic>?) ?? [];

    String? matchedUrl;
    int? matchedSize;
    String? sha256SumsUrl;

    final platLower = targetPlatform.toLowerCase();
    for (final rawAsset in assets) {
      if (rawAsset is! Map<String, dynamic>) continue;
      final assetName = (rawAsset['name'] as String? ?? '').toLowerCase();
      final downloadUrl = rawAsset['browser_download_url'] as String? ?? '';
      final size = rawAsset['size'] as int?;

      if (downloadUrl.isEmpty || !isTrustedReleaseUrl(downloadUrl)) continue;

      if (assetName == 'sha256sums.txt') {
        sha256SumsUrl = downloadUrl;
        continue;
      }

      if (matchedUrl != null) continue;

      if (platLower == 'android' && assetName.endsWith('.apk')) {
        matchedUrl = downloadUrl;
        matchedSize = size;
      } else if (platLower == 'linux' &&
          (assetName.endsWith('.tar.gz') ||
              assetName.endsWith('.appimage') ||
              assetName.endsWith('.deb'))) {
        matchedUrl = downloadUrl;
        matchedSize = size;
      } else if (platLower == 'windows' &&
          (assetName.endsWith('.msix') ||
              assetName.endsWith('.exe') ||
              (assetName.contains('windows') && assetName.endsWith('.zip')))) {
        matchedUrl = downloadUrl;
        matchedSize = size;
      } else if (platLower == 'macos' &&
          (assetName.endsWith('.dmg') ||
              (assetName.contains('macos') && assetName.endsWith('.zip')))) {
        matchedUrl = downloadUrl;
        matchedSize = size;
      }
    }

    // Root-cause fix: previously fell back to `assets.first`, which could offer
    // an Android APK on Linux/Windows or download SHA256SUMS.txt as an installer.
    // If no platform-matching binary exists, fall back strictly to trusted release html_url.
    if (matchedUrl == null) {
      final htmlUrl = json['html_url'] as String? ?? '';
      matchedUrl = isTrustedReleaseUrl(htmlUrl) ? htmlUrl : '';
    }

    // Check if mandatory flag is present in notes or tag
    final isMandatory = body.contains('[mandatory]') ||
        body.contains('CRITICAL UPDATE') ||
        body.contains('MANDATORY UPDATE');

    return UpdateInfo(
      version: '${semver.major}.${semver.minor}.${semver.patch}',
      buildNumber: remoteBuildNumber,
      releaseName: name,
      releaseNotes: body,
      publishedAt: publishedAt,
      downloadUrl: matchedUrl,
      fileSizeBytes: matchedSize,
      isMandatory: isMandatory,
      platform: targetPlatform,
      sha256SumsUrl: sha256SumsUrl,
    );
  }

  /// Parses a Supabase app_releases table row.
  static UpdateInfo fromSupabaseRow(Map<String, dynamic> row) {
    final versionStr = row['version']?.toString() ?? '1.0.0';
    final buildNum = (row['build_number'] as num?)?.toInt() ?? 0;
    final publishedStr = row['published_at']?.toString();
    final publishedAt = publishedStr != null
        ? DateTime.tryParse(publishedStr) ?? DateTime.now()
        : DateTime.now();

    return UpdateInfo(
      version: versionStr,
      buildNumber: buildNum,
      releaseName: row['release_name']?.toString() ?? 'v$versionStr',
      releaseNotes: row['release_notes']?.toString() ?? '',
      publishedAt: publishedAt,
      downloadUrl: row['download_url']?.toString() ?? '',
      fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt(),
      isMandatory: row['is_mandatory'] == true || row['is_mandatory'] == 1,
      platform: row['platform']?.toString() ?? 'all',
      minSupportedVersion: row['min_supported_version']?.toString(),
    );
  }
}
