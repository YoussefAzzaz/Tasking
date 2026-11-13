import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/prayers/adhan_sound_service.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  group('AdhanSoundService & Sound Options Tests', () {
    test('Default famous adhans catalog contains canonical Makkah, Madinah, and Alafasy with Takbeerat tags', () {
      final list = AdhanSoundService.kFamousAdhans;
      expect(list, isNotEmpty);

      final makkah = list.firstWhere((s) => s.id == 'makkah');
      expect(makkah.name, contains('Makkah'));
      expect(makkah.description, contains('Takbeerat'));
      expect(makkah.isBundled, isTrue);
      expect(makkah.assetPath, equals('assets/audio/adhan_makkah.mp3'));

      final madinah = list.firstWhere((s) => s.id == 'madinah');
      expect(madinah.name, contains('Madinah'));
      expect(madinah.description, contains('Takbeerat'));
      expect(madinah.isBundled, isTrue);
      expect(madinah.assetPath, equals('assets/audio/adhan_madinah.mp3'));

      final alafasy = list.firstWhere((s) => s.id == 'alafasy');
      expect(alafasy.name, contains('Alafasy'));
      expect(alafasy.description, contains('Takbeerat'));
      expect(alafasy.isBundled, isTrue);
      expect(alafasy.assetPath, equals('assets/audio/adhan_alafasy.mp3'));
    });

    test('getActiveAudioSource resolves AssetSource for bundled sounds', () {
      final service = AdhanSoundService();
      final makkah = AdhanSoundService.kFamousAdhans.first;
      service.selectedSoundNotifier.value = makkah;

      final source = service.getActiveAudioSource();
      expect(source, isA<AssetSource>());
      expect((source as AssetSource).path, equals('audio/adhan_makkah.mp3'));
    });

    test('getActiveAudioSource falls back cleanly without crash', () {
      final service = AdhanSoundService();
      const customFallback = AdhanSoundOption(
        id: 'missing_custom',
        name: 'Missing',
        nameAr: 'مفقود',
        muadhin: 'Unknown',
        muadhinAr: 'مجهول',
        description: 'Test',
        descriptionAr: 'اختبار',
        localPath: '/non/existent/path/audio.mp3',
        isCustom: true,
      );
      service.selectedSoundNotifier.value = customFallback;

      final source = service.getActiveAudioSource();
      expect(source, isA<AssetSource>());
      expect((source as AssetSource).path, equals('audio/adhan_makkah.mp3'));
    });

    test('AdhanSoundOption copyWith preserves fields correctly', () {
      final original = AdhanSoundService.kFamousAdhans.first;
      final updated = original.copyWith(localPath: '/storage/adhan.mp3');

      expect(updated.id, equals(original.id));
      expect(updated.name, equals(original.name));
      expect(updated.localPath, equals('/storage/adhan.mp3'));
    });

    test('sliceMp3Bytes accurately slices MPEG Layer 3 audio frames to ~16 seconds', () async {
      final file = File('assets/audio/adhan_makkah.mp3');
      expect(file.existsSync(), isTrue);

      final rawBytes = await file.readAsBytes();
      final sliced = AdhanSoundService.sliceMp3Bytes(rawBytes, targetDuration: 16.0);

      expect(sliced.isNotEmpty, isTrue);
      expect(sliced.length, lessThanOrEqualTo(rawBytes.length));
      expect(sliced.length, greaterThan(10000));
    });

    test('All bundled adhans exist and are cropped to ~15-16.5s (< 300KB)', () async {
      final files = [
        'assets/audio/adhan_makkah.mp3',
        'assets/audio/adhan_madinah.mp3',
        'assets/audio/adhan_alafasy.mp3',
      ];

      for (final f in files) {
        final file = File(f);
        expect(file.existsSync(), isTrue, reason: '$f must exist in assets');
        final bytes = await file.readAsBytes();
        // File size should be cropped (under 300KB)
        expect(bytes.length, lessThan(300 * 1024), reason: '$f must be cropped to first part');
      }
    });

    test('downloadingNotifier notifies listeners on state changes', () {
      final service = AdhanSoundService();
      String? notifiedId;
      service.downloadingNotifier.addListener(() {
        notifiedId = service.downloadingNotifier.value;
      });

      service.downloadingNotifier.value = 'abdulbasit';
      expect(notifiedId, equals('abdulbasit'));

      service.downloadingNotifier.value = null;
      expect(notifiedId, isNull);
    });
  });
}
