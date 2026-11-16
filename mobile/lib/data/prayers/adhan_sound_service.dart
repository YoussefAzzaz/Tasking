import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:axis/data/powersync_db.dart';

/// Represents a selectable Adhan notification sound option (bundled, downloadable, or user-custom).
class AdhanSoundOption {
  final String id;
  final String name;
  final String nameAr;
  final String muadhin;
  final String muadhinAr;
  final String description;
  final String descriptionAr;
  final String? assetPath;
  final String? remoteUrl;
  final String? localPath;
  final bool isBundled;
  final bool isCustom;

  const AdhanSoundOption({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.muadhin,
    required this.muadhinAr,
    required this.description,
    required this.descriptionAr,
    this.assetPath,
    this.remoteUrl,
    this.localPath,
    this.isBundled = false,
    this.isCustom = false,
  });

  AdhanSoundOption copyWith({
    String? localPath,
  }) {
    return AdhanSoundOption(
      id: id,
      name: name,
      nameAr: nameAr,
      muadhin: muadhin,
      muadhinAr: muadhinAr,
      description: description,
      descriptionAr: descriptionAr,
      assetPath: assetPath,
      remoteUrl: remoteUrl,
      localPath: localPath ?? this.localPath,
      isBundled: isBundled,
      isCustom: isCustom,
    );
  }
}

/// Centralized manager for Adhan sounds, preview playback, and custom device sound uploads.
class AdhanSoundService {
  static final AdhanSoundService _instance = AdhanSoundService._internal();
  factory AdhanSoundService() => _instance;
  AdhanSoundService._internal();

  AudioPlayer? _previewPlayer;
  String? _currentlyPreviewingId;
  Timer? _previewTimer;

  final ValueNotifier<String?> previewingNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> downloadingNotifier = ValueNotifier<String?>(null);

  /// Canonical curated famous Adhan list
  static final List<AdhanSoundOption> kFamousAdhans = [
    const AdhanSoundOption(
      id: 'alafasy',
      name: 'Sheikh Mishary Rashid Alafasy',
      nameAr: 'الشيخ مشاري راشد العفاسي',
      muadhin: 'Mishary Rashid Alafasy (Maqam Hijaz)',
      muadhinAr: 'مشاري راشد العفاسي (مقام الحجاز)',
      description: 'Heart-soothing authentic full Adhan in Maqam Hijaz',
      descriptionAr: 'أذان كامل عذب ومرتل بمقام الحجاز محبب لقلوب الملايين',
      assetPath: 'assets/audio/adhan_alafasy.mp3',
      isBundled: true,
    ),
    const AdhanSoundOption(
      id: 'makkah',
      name: 'Makkah Al-Mukarramah',
      nameAr: 'أذان مكة المكرمة (الحرم المكي)',
      muadhin: 'Sheikh Ali Mulla / Sheikh Yunus Khoja',
      muadhinAr: 'الشيخ علي ملا / الشيخ يونس خوجة',
      description: 'Canonical & timeless Grand Mosque Adhan',
      descriptionAr: 'الأذان الشرعي والتاريخي للمسجد الحرام بمكة المكرمة',
      assetPath: 'assets/audio/adhan_makkah.mp3',
      isBundled: true,
    ),
    const AdhanSoundOption(
      id: 'madinah',
      name: 'Al-Madinah Al-Munawwarah',
      nameAr: 'أذان المدينة المنورة (المسجد النبوي)',
      muadhin: 'Sheikh Abdul Majeed Al-Surayhi',
      muadhinAr: 'الشيخ عبد المجيد السريحي',
      description: 'Serene and spiritual Prophet’s Mosque Adhan',
      descriptionAr: 'أذان المسجد النبوي الشريف بروحانية وسكينة عالية',
      assetPath: 'assets/audio/adhan_madinah.mp3',
      isBundled: true,
    ),
    const AdhanSoundOption(
      id: 'abdulbasit',
      name: 'Sheikh Abdul Basit Abdus Samad',
      nameAr: 'الشيخ عبد الباسط عبد الصمد',
      muadhin: 'Abdul Basit (Historic Egyptian Maqam)',
      muadhinAr: 'أسطورة التلاوة عبد الباسط عبد الصمد',
      description: 'Golden era resonant historic masterpiece',
      descriptionAr: 'تحفة صوتية تاريخية من العصر الذهبي للقراء بمصر',
      remoteUrl: 'https://archive.org/download/4-9-13MakkahDuhurAdhanSheikhYunusKhoja/4-9-13MakkahDuhurAdhanSheikhYunusKhoja.mp3',
      isBundled: false,
    ),
    const AdhanSoundOption(
      id: 'alaqsa',
      name: 'Al-Aqsa Mosque (Jerusalem)',
      nameAr: 'أذان المسجد الأقصى المبارك (القدس)',
      muadhin: 'Mu’adhin of Blessed Al-Aqsa',
      muadhinAr: 'مؤذنو المسجد الأقصى الشريف',
      description: 'Historic Adhan echoing from the holy city',
      descriptionAr: 'أذان مهيب يصدح من رحاب المسجد الأقصى المبارك',
      remoteUrl: 'https://archive.org/download/February12012MaghribAdhaan/SheikhFayda_Maghrib_2-1-12.mp3',
      isBundled: false,
    ),
  ];

  late ValueNotifier<AdhanSoundOption> selectedSoundNotifier =
      ValueNotifier<AdhanSoundOption>(kFamousAdhans.first);

  AdhanSoundOption get currentSound => selectedSoundNotifier.value;

  /// Initializes sound selection from SQLite
  Future<void> init() async {
    try {
      final rows = await db.getAll('SELECT * FROM prayer_settings WHERE id = ?', ['current']);
      if (rows.isNotEmpty) {
        final row = rows.first;
        final soundId = row['adhan_sound_id'] as String?;
        final soundTitle = row['adhan_sound_title'] as String?;
        final soundPath = row['adhan_sound_path'] as String?;
        final soundType = row['adhan_sound_type'] as String?;

        if (soundId != null && soundId.isNotEmpty) {
          if (soundType == 'custom' && soundPath != null && File(soundPath).existsSync()) {
            selectedSoundNotifier.value = AdhanSoundOption(
              id: soundId,
              name: soundTitle ?? 'Custom Sound',
              nameAr: soundTitle ?? 'صوت مخصص',
              muadhin: 'User Uploaded Sound',
              muadhinAr: 'صوت مخصص من هاتفك',
              description: 'Custom uploaded audio from phone storage',
              descriptionAr: 'ملف صوتي تم اختياره من ذاكرة الهاتف',
              localPath: soundPath,
              isCustom: true,
            );
            return;
          }

          final match = kFamousAdhans.firstWhere(
            (s) => s.id == soundId,
            orElse: () => kFamousAdhans.first,
          );

          if (soundPath != null && soundPath.isNotEmpty && File(soundPath).existsSync()) {
            selectedSoundNotifier.value = match.copyWith(localPath: soundPath);
          } else {
            selectedSoundNotifier.value = match;
          }
        }
      }
    } catch (e) {
      debugPrint('[AdhanSoundService] init notice: $e');
    }
  }

  /// Sets the active sound and saves preference in SQLite.
  /// If the sound is a remote URL and not yet downloaded, downloads and crops it to the first part (~16s).
  Future<void> selectSound(AdhanSoundOption sound) async {
    AdhanSoundOption targetSound = sound;

    if (sound.remoteUrl != null &&
        (sound.localPath == null || !File(sound.localPath!).existsSync())) {
      downloadingNotifier.value = sound.id;
      final downloaded = await downloadAndCropRemoteSound(sound);
      downloadingNotifier.value = null;
      if (downloaded != null) {
        targetSound = downloaded;
      }
    }

    selectedSoundNotifier.value = targetSound;

    try {
      final soundType = targetSound.isCustom
          ? 'custom'
          : (targetSound.isBundled ? 'bundled' : 'downloaded');
      final path = targetSound.localPath ?? targetSound.assetPath ?? '';

      await db.execute('''
        UPDATE prayer_settings 
        SET adhan_sound_id = ?,
            adhan_sound_title = ?,
            adhan_sound_path = ?,
            adhan_sound_type = ?
        WHERE id = 'current'
      ''', [targetSound.id, targetSound.name, path, soundType]);
    } catch (e) {
      debugPrint('[AdhanSoundService] selectSound error: $e');
    }
  }

  /// Downloads a remote Adhan MP3 and crops it to the opening Takbeerat (~16 seconds),
  /// saving the cropped audio locally in the app documents directory.
  Future<AdhanSoundOption?> downloadAndCropRemoteSound(AdhanSoundOption sound) async {
    if (sound.remoteUrl == null) return null;
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(sound.remoteUrl!));
      final response = await request.close();

      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final bytesBuilder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytesBuilder.add(chunk);
        // We only need the first ~1MB to extract ~16 seconds of MPEG audio
        if (bytesBuilder.length > 1024 * 1024) {
          break;
        }
      }
      client.close(force: true);

      final rawBytes = bytesBuilder.toBytes();
      final croppedBytes = sliceMp3Bytes(rawBytes, targetDuration: 45.0);

      final docsDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docsDir.path}/custom_adhan_sounds');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final destPath = '${audioDir.path}/adhan_${sound.id}_short.mp3';
      await File(destPath).writeAsBytes(croppedBytes);

      return sound.copyWith(localPath: destPath);
    } catch (e) {
      debugPrint('[AdhanSoundService] downloadAndCropRemoteSound error: $e');
      return null;
    }
  }

  /// Plays or pauses preview for a given sound option.
  /// Automatically stops preview after ~45 seconds to keep preview bounded.
  Future<void> togglePreview(AdhanSoundOption sound) async {
    if (_currentlyPreviewingId == sound.id) {
      await stopPreview();
      return;
    }

    await stopPreview();
    _previewPlayer ??= AudioPlayer();
    _currentlyPreviewingId = sound.id;
    previewingNotifier.value = sound.id;

    try {
      Source source;
      if (sound.localPath != null && File(sound.localPath!).existsSync()) {
        source = DeviceFileSource(sound.localPath!);
      } else if (sound.assetPath != null) {
        final cleanAsset = sound.assetPath!.replaceFirst('assets/', '');
        source = AssetSource(cleanAsset);
      } else if (sound.remoteUrl != null) {
        source = UrlSource(sound.remoteUrl!);
      } else {
        source = AssetSource('audio/adhan_alafasy.mp3');
      }

      await _previewPlayer!.stop();
      await _previewPlayer!.play(source);

      // Auto-stop preview after 45 seconds
      _previewTimer?.cancel();
      _previewTimer = Timer(const Duration(seconds: 45), () {
        stopPreview();
      });

      _previewPlayer!.onPlayerComplete.listen((_) {
        _previewTimer?.cancel();
        _currentlyPreviewingId = null;
        previewingNotifier.value = null;
      });
    } catch (e) {
      debugPrint('[AdhanSoundService] preview error: $e');
      _previewTimer?.cancel();
      _currentlyPreviewingId = null;
      previewingNotifier.value = null;
    }
  }

  /// Stops current preview playback
  Future<void> stopPreview() async {
    _previewTimer?.cancel();
    _previewTimer = null;
    _currentlyPreviewingId = null;
    previewingNotifier.value = null;
    if (_previewPlayer != null) {
      try {
        await _previewPlayer!.stop();
      } catch (_) {}
    }
  }

  /// Lets the user pick an audio file from phone storage and sets it as the active Adhan sound.
  /// If it is an MP3 file, it is automatically cropped to ~16 seconds (Takbeerat).
  Future<AdhanSoundOption?> pickAndSetCustomSound() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select Adhan Sound / اختر صوت الأذان',
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg', 'aac'],
      );

      if (files.isEmpty) return null;
      final file = files.first;
      final originalPath = file.path;
      if (originalPath == null) return null;

      final docsDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docsDir.path}/custom_adhan_sounds');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final fileName = file.name;
      final destPath = '${audioDir.path}/custom_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      if (fileName.toLowerCase().endsWith('.mp3')) {
        final rawBytes = await File(originalPath).readAsBytes();
        final croppedBytes = sliceMp3Bytes(rawBytes, targetDuration: 45.0);
        await File(destPath).writeAsBytes(croppedBytes);
      } else {
        await File(originalPath).copy(destPath);
      }

      final customOption = AdhanSoundOption(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: fileName,
        nameAr: fileName,
        muadhin: 'Custom Phone Audio',
        muadhinAr: 'صوت مخصص من الهاتف',
        description: 'Uploaded from device storage (Short Takbeerat)',
        descriptionAr: 'تم اختياره من ذاكرة الهاتف (مقطع التكبيرات الأول)',
        localPath: destPath,
        isCustom: true,
      );

      await selectSound(customOption);
      return customOption;
    } catch (e) {
      debugPrint('[AdhanSoundService] pickCustomSound error: $e');
      return null;
    }
  }

  /// Resolves the actual playable [Source] for [AudioPlayer] for alarms
  Source getActiveAudioSource() {
    final sound = currentSound;
    if (sound.localPath != null && File(sound.localPath!).existsSync()) {
      return DeviceFileSource(sound.localPath!);
    }
    if (sound.assetPath != null) {
      final clean = sound.assetPath!.replaceFirst('assets/', '');
      return AssetSource(clean);
    }
    return AssetSource('audio/adhan_alafasy.mp3');
  }

  /// Pure Dart MPEG frame slicer to truncate MP3 audio cleanly at frame boundaries
  /// to the first part (~16 seconds / Takbeerat).
  static Uint8List sliceMp3Bytes(Uint8List data, {double targetDuration = 16.0}) {
    int pos = 0;
    Uint8List id3Header = Uint8List(0);

    if (data.length >= 10 &&
        data[0] == 0x49 &&
        data[1] == 0x44 &&
        data[2] == 0x33) {
      final tagSize = ((data[6] & 0x7F) << 21) |
          ((data[7] & 0x7F) << 14) |
          ((data[8] & 0x7F) << 7) |
          (data[9] & 0x7F);
      final id3Len = 10 + tagSize;
      if (id3Len <= data.length) {
        id3Header = Uint8List.sublistView(data, 0, id3Len);
        pos = id3Len;
      }
    }

    const brTableM1L3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
    const brTableM2L3 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
    const srTableM1 = [44100, 48000, 32000];
    const srTableM2 = [22050, 24000, 16000];
    const srTableM25 = [11025, 12000, 8000];

    final frames = <Uint8List>[];
    double totalSeconds = 0.0;

    while (pos < data.length - 4) {
      if (data[pos] == 0xFF && (data[pos + 1] & 0xE0) == 0xE0) {
        final header = (data[pos] << 24) |
            (data[pos + 1] << 16) |
            (data[pos + 2] << 8) |
            data[pos + 3];

        final ver = (header >> 19) & 3;
        final layer = (header >> 17) & 3;
        final brIdx = (header >> 12) & 0xF;
        final srIdx = (header >> 10) & 3;
        final pad = (header >> 9) & 1;

        if (layer == 1 && brIdx >= 1 && brIdx < 15 && srIdx >= 0 && srIdx < 3) {
          int sampleRate;
          int bitrate;
          int frameLen;
          double frameDur;

          if (ver == 3) {
            sampleRate = srTableM1[srIdx];
            bitrate = brTableM1L3[brIdx] * 1000;
            frameLen = ((144 * bitrate) ~/ sampleRate) + pad;
            frameDur = 1152 / sampleRate;
          } else if (ver == 0 || ver == 2) {
            sampleRate = ver == 2 ? srTableM2[srIdx] : srTableM25[srIdx];
            bitrate = brTableM2L3[brIdx] * 1000;
            frameLen = ((72 * bitrate) ~/ sampleRate) + pad;
            frameDur = 576 / sampleRate;
          } else {
            pos++;
            continue;
          }

          if (pos + frameLen > data.length) {
            break;
          }

          final frameBytes = Uint8List.sublistView(data, pos, pos + frameLen);

          // Check for Xing/Info header in first frame and skip it to prevent misreporting duration
          if (frames.isEmpty) {
            final isXing = _containsAscii(frameBytes, 'Xing') || _containsAscii(frameBytes, 'Info');
            if (isXing) {
              pos += frameLen;
              continue;
            }
          }

          if (totalSeconds + frameDur > targetDuration) {
            break;
          }

          frames.add(frameBytes);
          totalSeconds += frameDur;
          pos += frameLen;
          continue;
        }
      }
      pos++;
    }

    if (frames.isEmpty) {
      return data;
    }

    final builder = BytesBuilder(copy: false);
    if (id3Header.isNotEmpty) builder.add(id3Header);
    for (final f in frames) {
      builder.add(f);
    }
    return builder.toBytes();
  }

  static bool _containsAscii(Uint8List data, String target) {
    final targetBytes = target.codeUnits;
    for (int i = 0; i <= data.length - targetBytes.length; i++) {
      bool match = true;
      for (int j = 0; j < targetBytes.length; j++) {
        if (data[i + j] != targetBytes[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }
}
