import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Background Neural Soundscape generator & player for ambient focus entrainment.
/// Generates procedural soothing audio locally in memory with zero clicks and seamless looping.
class NeuralSoundService {
  static final NeuralSoundService _instance = NeuralSoundService._();
  factory NeuralSoundService() => _instance;
  NeuralSoundService._();

  AudioPlayer? _audioPlayer;
  String? _currentTrack;
  double _volume = 0.7;

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentTrackNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(0.7);

  bool get isPlaying => isPlayingNotifier.value;
  String? get currentTrack => currentTrackNotifier.value;
  double get volume => _volume;

  /// Normalizes legacy or aliased track names to current relaxing sounds
  static String normalizeTrackName(String name) {
    switch (name) {
      case 'Deep Theta 40Hz':
        return 'Alpha Wave 10Hz';
      case 'Neon Rain':
        return 'Gentle Rain';
      case 'Quantum Void':
        return 'Deep Space';
      case 'Cyber Coffee':
        return 'Campfire Glow';
      default:
        return name;
    }
  }

  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    volumeNotifier.value = _volume;
    if (_audioPlayer != null) {
      try {
        await _audioPlayer!.setVolume(_volume);
      } catch (_) {}
    }
  }

  Future<void> play(String rawTrackName) async {
    final trackName = normalizeTrackName(rawTrackName);
    await stop();

    try {
      final wavFile = await _getOrGenerateWav(trackName);
      if (!await wavFile.exists()) return;

      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.stop();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setVolume(_volume);
      await _audioPlayer!.play(DeviceFileSource(wavFile.path));

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
  }

  Future<void> toggle(String rawTrackName) async {
    final trackName = normalizeTrackName(rawTrackName);
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
    // Version suffix v2 ensures any previously generated harsh sounds are regenerated with relaxing sounds
    final file = File('${tempDir.path}/neural_v2_$safeName.wav');
    if (await file.exists() && (await file.length()) > 1000) {
      return file;
    }

    final bytes = await compute(_generateWavBytesIsolate, trackName);
    await file.writeAsBytes(bytes);
    return file;
  }
}

/// Generates high-quality procedural ambient soundscape WAV buffers in an isolate
Uint8List _generateWavBytesIsolate(String trackName) {
  const sampleRate = 22050;
  const durationSeconds = 6; // 6-second seamlessly looping buffer
  const totalSamples = sampleRate * durationSeconds;

  final samples = Int16List(totalSamples);
  final random = Random(42);

  final name = trackName.toLowerCase();

  if (name.contains('ocean') || name.contains('wave') && !name.contains('alpha')) {
    // 🌊 Ocean Surf & Waves: Rhythmic, hypnotic tidal swell
    double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
    double lp = 0;
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final white = random.nextDouble() * 2.0 - 1.0;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      final pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.07;
      b6 = white * 0.115926;

      // 6-second wave cycle: smooth breathing surge and retreat
      final swell = 0.30 +
          0.70 * pow(0.5 + 0.5 * sin(2 * pi * t / durationSeconds - pi / 2), 2.2);
      final alpha = 0.08 + 0.14 * swell;
      lp = (1.0 - alpha) * lp + alpha * pink;

      final sampleVal = (lp * swell * 32767 * 1.6).toInt();
      samples[i] = sampleVal.clamp(-32768, 32767);
    }
  } else if (name.contains('fire') || name.contains('campfire') || name.contains('ember')) {
    // 🔥 Campfire Glow: Warm low frequency rumble + gentle organic wood crackles
    double lp = 0;
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final flame = sin(2 * pi * 52 * t) * 0.06 + sin(2 * pi * 84 * t) * 0.04;
      final white = random.nextDouble() * 2.0 - 1.0;
      lp = 0.95 * lp + 0.05 * (white * 0.06);

      double crackle = 0;
      if (random.nextDouble() < 0.0014) {
        crackle = (random.nextDouble() * 0.40 - 0.20);
      }
      final sampleVal = ((flame + lp + crackle) * 32767).toInt();
      samples[i] = sampleVal.clamp(-32768, 32767);
    }
  } else if (name.contains('space') || name.contains('void') || name.contains('cosmic')) {
    // 🌌 Deep Space Drone: Velvet-smooth warm ambient pad chord (A1 + E2 + A2)
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final lfo = 0.85 + 0.15 * sin(2 * pi * 0.12 * t);
      final lfo2 = 0.80 + 0.20 * cos(2 * pi * 0.07 * t);
      final s1 = sin(2 * pi * 55.0 * t);
      final s2 = 0.45 * sin(2 * pi * 82.5 * t + 0.5);
      final s3 = 0.25 * sin(2 * pi * 110.0 * t + 1.2);
      final s4 = 0.10 * sin(2 * pi * 165.0 * t + 2.0);
      final val = (s1 * lfo + s2 * lfo2 + s3 + s4) * 0.24 * 32767;
      samples[i] = val.toInt().clamp(-32768, 32767);
    }
  } else if (name.contains('zen') || name.contains('bowl') || name.contains('temple')) {
    // 🧘 Zen Garden: 432Hz meditative singing bowl resonance with soft acoustic decay
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final strikeCycle = t % 3.0;
      final decay = exp(-strikeCycle * 1.3);
      final bowl = sin(2 * pi * 432 * t) * 0.45 +
          sin(2 * pi * 864 * t) * 0.22 +
          sin(2 * pi * 1296 * t) * 0.10;
      final air = sin(2 * pi * 90 * t) * 0.04;
      final val = (bowl * decay * 0.42 + air) * 32767;
      samples[i] = val.toInt().clamp(-32768, 32767);
    }
  } else if (name.contains('cricket') || name.contains('night') || name.contains('meadow')) {
    // 🌙 Night Crickets: Tranquil nocturnal air with soft distant meadow cricket chirps
    double lp = 0;
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final white = random.nextDouble() * 2.0 - 1.0;
      lp = 0.96 * lp + 0.04 * (white * 0.04);
      final chirpCycle = t % 1.5;
      double cricket = 0;
      if (chirpCycle < 0.30) {
        final pulse = 0.5 + 0.5 * sin(2 * pi * 24 * chirpCycle);
        cricket = sin(2 * pi * 4400 * t) * pulse * 0.05;
      }
      final val = (lp + cricket) * 32767;
      samples[i] = val.toInt().clamp(-32768, 32767);
    }
  } else if (name.contains('alpha') || name.contains('theta')) {
    // 🧠 Alpha Wave 10Hz: Therapeutic 10Hz Alpha relaxation wave on warm harmonic tone
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final alpha = 0.78 + 0.22 * sin(2 * pi * 10 * t);
      final tone = sin(2 * pi * 108 * t) * 0.55 + sin(2 * pi * 54 * t) * 0.35;
      final val = tone * alpha * 0.32 * 32767;
      samples[i] = val.toInt().clamp(-32768, 32767);
    }
  } else if (name.contains('brown') || name.contains('noise')) {
    // 🌊 Deep Brown Noise: Rich, warm, low-frequency sound curtain that eliminates background chatter
    double brown = 0;
    for (int i = 0; i < totalSamples; i++) {
      final white = random.nextDouble() * 2.0 - 1.0;
      brown = (brown + 0.02 * white) * 0.985;
      final sampleVal = (brown * 32767 * 2.2).toInt();
      samples[i] = sampleVal.clamp(-32768, 32767);
    }
  } else {
    // 🌧️ Default: Gentle Forest Rain - Soft, warm raindrops without harsh highs
    double b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
    double lp = 0;
    for (int i = 0; i < totalSamples; i++) {
      final white = random.nextDouble() * 2.0 - 1.0;
      b0 = 0.99886 * b0 + white * 0.0555179;
      b1 = 0.99332 * b1 + white * 0.0750759;
      b2 = 0.96900 * b2 + white * 0.1538520;
      b3 = 0.86650 * b3 + white * 0.3104856;
      b4 = 0.55000 * b4 + white * 0.5329522;
      b5 = -0.7616 * b5 - white * 0.0168980;
      final pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.06;
      b6 = white * 0.115926;
      lp = 0.85 * lp + 0.15 * pink;

      double drop = 0;
      if (random.nextDouble() < 0.0007) {
        drop = (random.nextDouble() * 0.12 - 0.06);
      }
      final sampleVal = ((lp + drop) * 32767).toInt();
      samples[i] = sampleVal.clamp(-32768, 32767);
    }
  }

  // Smooth 150ms crossfade at edges to guarantee 100% click-free seamless loop
  final fadeSamples = (sampleRate * 0.15).toInt();
  for (int i = 0; i < fadeSamples; i++) {
    final factor = i / fadeSamples;
    samples[i] = (samples[i] * factor).toInt();
    final endIdx = totalSamples - 1 - i;
    samples[endIdx] = (samples[endIdx] * factor).toInt();
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
