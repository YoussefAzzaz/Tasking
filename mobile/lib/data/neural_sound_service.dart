import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Background Neural Soundscape generator & player for ambient focus entrainment
class NeuralSoundService {
  static final NeuralSoundService _instance = NeuralSoundService._();
  factory NeuralSoundService() => _instance;
  NeuralSoundService._();

  Process? _activeProcess;
  AudioPlayer? _audioPlayer;
  String? _currentTrack;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentTrackNotifier =
      ValueNotifier<String?>(null);

  bool get isPlaying => isPlayingNotifier.value;
  String? get currentTrack => currentTrackNotifier.value;

  Future<void> play(String trackName) async {
    await stop();

    try {
      final wavFile = await _getOrGenerateWav(trackName);
      if (!await wavFile.exists()) return;

      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isLinux) {
        _audioPlayer ??= AudioPlayer();
        await _audioPlayer!.stop();
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer!.play(DeviceFileSource(wavFile.path));
      } else if (Platform.isWindows) {
        try {
          _audioPlayer ??= AudioPlayer();
          await _audioPlayer!.stop();
          await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer!.play(DeviceFileSource(wavFile.path));
        } catch (_) {
          final path = wavFile.path.replaceAll('/', '\\');
          _activeProcess = await Process.start(
            'powershell',
            [
              '-NoProfile',
              '-NonInteractive',
              '-Command',
              "\$sp = New-Object System.Media.SoundPlayer '$path'; \$sp.PlayLooping(); while(\$true){ Start-Sleep -Seconds 1 }",
            ],
          );
        }
      }
      _currentTrack = trackName;
      currentTrackNotifier.value = trackName;
      isPlayingNotifier.value = true;
    } catch (_) {
      isPlayingNotifier.value = false;
    }
  }

  Future<void> stop() async {
    isPlayingNotifier.value = false;
    currentTrackNotifier.value = null;
    _currentTrack = null;
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.stop();
      } catch (_) {}
    }
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill();
      } catch (_) {}
      _activeProcess = null;
    }
  }

  Future<void> toggle(String trackName) async {
    if (isPlaying && _currentTrack == trackName) {
      await stop();
    } else {
      await play(trackName);
    }
  }

  Future<File> _getOrGenerateWav(String trackName) async {
    final tempDir = await getTemporaryDirectory();
    final safeName =
        trackName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final file = File('${tempDir.path}/neural_$safeName.wav');
    if (await file.exists() && (await file.length()) > 1000) {
      return file;
    }

    final bytes = _generateWavBytes(trackName);
    await file.writeAsBytes(bytes);
    return file;
  }

  Uint8List _generateWavBytes(String trackName) {
    const sampleRate = 22050;
    const durationSeconds = 4; // 4 second looping buffer
    const totalSamples = sampleRate * durationSeconds;

    final samples = Int16List(totalSamples);
    final random = Random(42);

    if (trackName.contains('Theta')) {
      // Deep Theta 40Hz: 200Hz carrier tone modulated with 40Hz gamma/theta entrainment
      for (int i = 0; i < totalSamples; i++) {
        final t = i / sampleRate;
        final carrier = sin(2 * pi * 200 * t);
        final mod = 0.5 + 0.5 * sin(2 * pi * 40 * t);
        final sampleVal = (carrier * mod * 0.42 * 32767).toInt();
        samples[i] = sampleVal.clamp(-32768, 32767);
      }
    } else if (trackName.contains('Rain')) {
      // Neon Rain: pink/brown filtered noise simulating rain
      double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
      for (int i = 0; i < totalSamples; i++) {
        final white = (random.nextDouble() * 2.0 - 1.0);
        b0 = 0.99886 * b0 + white * 0.0555179;
        b1 = 0.99332 * b1 + white * 0.0750759;
        b2 = 0.96900 * b2 + white * 0.1538520;
        b3 = 0.86650 * b3 + white * 0.3104856;
        b4 = 0.55000 * b4 + white * 0.5329522;
        b5 = -0.7616 * b5 - white * 0.0168980;
        final pink =
            (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.08;
        b6 = white * 0.115926;
        final sampleVal = (pink * 32767).toInt();
        samples[i] = sampleVal.clamp(-32768, 32767);
      }
    } else if (trackName.contains('Void')) {
      // Quantum Void: deep 55Hz sub-bass drone with resonant harmonic overtones
      for (int i = 0; i < totalSamples; i++) {
        final t = i / sampleRate;
        final lfo = 0.85 + 0.15 * sin(2 * pi * 0.25 * t);
        final s1 = sin(2 * pi * 55 * t);
        final s2 = 0.35 * sin(2 * pi * 110 * t);
        final s3 = 0.15 * sin(2 * pi * 165 * t);
        final val = (s1 + s2 + s3) * lfo * 0.40 * 32767;
        samples[i] = val.toInt().clamp(-32768, 32767);
      }
    } else {
      // Cyber Coffee: warm ambient cafe low-mid frequency tone + soft vinyl crackle
      for (int i = 0; i < totalSamples; i++) {
        final t = i / sampleRate;
        double hum =
            0.25 * sin(2 * pi * 120 * t) + 0.12 * sin(2 * pi * 240 * t);
        if (random.nextDouble() < 0.003) {
          hum += (random.nextDouble() * 0.4 - 0.2);
        }
        final val = hum * 0.45 * 32767;
        samples[i] = val.toInt().clamp(-32768, 32767);
      }
    }

    return _buildWavHeader(samples, sampleRate);
  }

  Uint8List _buildWavHeader(Int16List samples, int sampleRate) {
    final byteData = ByteData(44 + samples.length * 2);
    // RIFF header
    byteData.setUint8(0, 0x52); // R
    byteData.setUint8(1, 0x49); // I
    byteData.setUint8(2, 0x46); // F
    byteData.setUint8(3, 0x46); // F
    byteData.setUint32(4, 36 + samples.length * 2, Endian.little);
    byteData.setUint8(8, 0x57); // W
    byteData.setUint8(9, 0x41); // A
    byteData.setUint8(10, 0x56); // V
    byteData.setUint8(11, 0x45); // E

    // fmt subchunk
    byteData.setUint8(12, 0x66); // f
    byteData.setUint8(13, 0x6D); // m
    byteData.setUint8(14, 0x74); // t
    byteData.setUint8(15, 0x20); // ' '
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little); // PCM
    byteData.setUint16(22, 1, Endian.little); // Mono
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little); // 16-bit

    // data subchunk
    byteData.setUint8(36, 0x64); // d
    byteData.setUint8(37, 0x61); // a
    byteData.setUint8(38, 0x74); // t
    byteData.setUint8(39, 0x61); // a
    byteData.setUint32(40, samples.length * 2, Endian.little);

    int offset = 44;
    for (int i = 0; i < samples.length; i++) {
      byteData.setInt16(offset, samples[i], Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }
}
