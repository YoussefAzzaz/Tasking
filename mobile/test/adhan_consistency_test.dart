import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/prayers/adhan_notification_channels.dart';
import 'package:axis/data/prayers/adhan_sound_service.dart';

void main() {
  group('Adhan Notification Channel & Asset Consistency Tests', () {
    test('all 5 daily prayers resolve matching sound channels for each preset', () {
      const prayerOrders = [1, 2, 3, 4, 5]; // Fajr, Dhuhr, Asr, Maghrib, Isha
      for (final sound in AdhanSoundService.kFamousAdhans) {
        final expectedRawSound = switch (sound.id) {
          'alafasy' => 'resource://raw/res_adhan_alafasy',
          'madinah' => 'resource://raw/res_adhan_madinah',
          _ => 'resource://raw/res_adhan',
        };
        final channels = AdhanNotificationChannels.buildChannels();
        final byKey = {for (final c in channels) c.channelKey: c};

        for (final order in prayerOrders) {
          final isFajr = order == 1;
          final key = AdhanNotificationChannels.channelKeyFor(
            soundId: sound.id,
            isFajr: isFajr,
          );
          expect(byKey.containsKey(key), isTrue,
              reason: 'Missing channel $key for ${sound.id}');
          expect(byKey[key]!.soundSource, expectedRawSound,
              reason: 'Prayer $order used mismatched sound for ${sound.id}');
          expect(
            AdhanNotificationChannels.isAnyAdhanChannel(key),
            isTrue,
            reason: 'Channel $key must be recognized by NotificationController',
          );
        }
      }
    });

    test('bundled Adhan asset files and Android res/raw audio files all exist', () {
      const expectedFiles = [
        'assets/audio/adhan_alafasy.mp3',
        'assets/audio/adhan_makkah.mp3',
        'assets/audio/adhan_madinah.mp3',
        'android/app/src/main/res/raw/res_adhan.mp3',
        'android/app/src/main/res/raw/res_adhan_alafasy.mp3',
        'android/app/src/main/res/raw/res_adhan_madinah.mp3',
      ];
      for (final relPath in expectedFiles) {
        final file = File(relPath);
        expect(file.existsSync(), isTrue, reason: 'Missing audio file: $relPath');
        expect(file.lengthSync(), greaterThan(10000),
            reason: 'Audio file looks empty/corrupt: $relPath');
      }
    });

    test('selectSound invokes onSoundSelectionChanged to refresh all 5 prayer schedules', () async {
      final soundService = AdhanSoundService();
      var refreshedCount = 0;
      soundService.onSoundSelectionChanged = () {
        refreshedCount++;
      };
      addTearDown(() => soundService.onSoundSelectionChanged = null);

      final madinah = AdhanSoundService.kFamousAdhans
          .firstWhere((s) => s.id == 'madinah');
      await soundService.selectSound(madinah);
      expect(refreshedCount, 1);
      expect(soundService.currentSound.id, 'madinah');
    });
  });
}
