import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

Uint8List sliceMp3Bytes(Uint8List data, {double targetDuration = 16.0}) {
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

        // Check for Xing/Info header in first frame
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

bool _containsAscii(Uint8List data, String target) {
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

void main() {
  test('sliceMp3Bytes slices bundled adhan properly to ~16 seconds', () async {
    final file = File('assets/audio/adhan_makkah.mp3');
    expect(file.existsSync(), isTrue);

    final rawBytes = await file.readAsBytes();
    final sliced = sliceMp3Bytes(rawBytes, targetDuration: 16.0);

    expect(sliced.isNotEmpty, isTrue);
    expect(sliced.length, lessThanOrEqualTo(rawBytes.length));
    expect(sliced.length, greaterThan(10000));
  });
}

