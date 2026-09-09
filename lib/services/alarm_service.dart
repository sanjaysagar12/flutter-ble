import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

enum AlarmReason { disconnected, outOfRange }

/// Fired by a controller (BLE or Classic Bluetooth) whenever it triggers
/// the alarm, so the UI layer can show a matching dialog.
typedef AlarmTriggeredCallback = void Function(
    String deviceName, AlarmReason reason);

/// Generates and plays a looping alarm tone. The tone is a synthesized
/// sine wave WAV, so the app needs no bundled audio asset.
class AlarmService {
  AlarmService() {
    _player.setReleaseMode(ReleaseMode.loop);
  }

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    try {
      final bytes = _generateSineWave(440, 1.0);
      await _player.play(BytesSource(bytes));
    } catch (_) {
      _isPlaying = false;
      rethrow;
    }
  }

  Future<void> stop() async {
    _isPlaying = false;
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }

  // Generates a simple WAV file in memory with a sine wave.
  Uint8List _generateSineWave(double frequency, double durationSeconds) {
    const int sampleRate = 44100;
    const int numChannels = 1;
    final int numSamples = (durationSeconds * sampleRate).toInt();
    final int byteRate = sampleRate * numChannels * 2; // 16-bit
    final int blockAlign = numChannels * 2;
    final int dataSize = numSamples * blockAlign;
    final int fileSize = 36 + dataSize;

    final ByteData byteData = ByteData(44 + dataSize);

    // RIFF chunk
    byteData.setUint8(0, 0x52); // R
    byteData.setUint8(1, 0x49); // I
    byteData.setUint8(2, 0x46); // F
    byteData.setUint8(3, 0x46); // F
    byteData.setUint32(4, fileSize, Endian.little);
    byteData.setUint8(8, 0x57); // W
    byteData.setUint8(9, 0x41); // A
    byteData.setUint8(10, 0x56); // V
    byteData.setUint8(11, 0x45); // E

    // fmt chunk
    byteData.setUint8(12, 0x66); // f
    byteData.setUint8(13, 0x6d); // m
    byteData.setUint8(14, 0x74); // t
    byteData.setUint8(15, 0x20); // space
    byteData.setUint32(16, 16, Endian.little); // chunk size
    byteData.setUint16(20, 1, Endian.little); // audio format (PCM)
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    byteData.setUint8(36, 0x64); // d
    byteData.setUint8(37, 0x61); // a
    byteData.setUint8(38, 0x74); // t
    byteData.setUint8(39, 0x61); // a
    byteData.setUint32(40, dataSize, Endian.little);

    // Samples
    int offset = 44;
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double sample = sin(2 * pi * frequency * t);
      final int sampleInt = (sample * 32767).toInt();
      byteData.setInt16(offset, sampleInt, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }
}
