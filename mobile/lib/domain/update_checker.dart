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

    final platLower = targetPlatform.toLowerCase();
    for (final rawAsset in assets) {
      if (rawAsset is! Map<String, dynamic>) continue;
      final assetName = (rawAsset['name'] as String? ?? '').toLowerCase();
      final downloadUrl = rawAsset['browser_download_url'] as String? ?? '';
      final size = rawAsset['size'] as int?;

      if (downloadUrl.isEmpty) continue;

      if (platLower == 'android' && assetName.endsWith('.apk')) {
        matchedUrl = downloadUrl;
        matchedSize = size;
        break;
      } else if (platLower == 'linux' &&
          (assetName.endsWith('.tar.gz') ||
              assetName.endsWith('.appimage') ||
              assetName.endsWith('.deb'))) {
        matchedUrl = downloadUrl;
        matchedSize = size;
        break;
      } else if (platLower == 'windows' &&
          (assetName.endsWith('.msix') ||
              assetName.endsWith('.exe') ||
              (assetName.contains('windows') && assetName.endsWith('.zip')))) {
        matchedUrl = downloadUrl;
        matchedSize = size;
        break;
      } else if (platLower == 'macos' &&
          (assetName.endsWith('.dmg') ||
              (assetName.contains('macos') && assetName.endsWith('.zip')))) {
        matchedUrl = downloadUrl;
        matchedSize = size;
        break;
      }
    }

    // Fallback: if no specific asset matched for this platform, look for general asset or tag link
    if (matchedUrl == null && assets.isNotEmpty) {
      final first = assets.first as Map<String, dynamic>;
      matchedUrl = first['browser_download_url'] as String?;
      matchedSize = first['size'] as int?;
    }

    matchedUrl ??= json['html_url'] as String? ?? '';

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
