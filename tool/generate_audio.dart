import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 44100;
  const durationSeconds = 1.2;
  final numSamples = (sampleRate * durationSeconds).toInt();
  
  // 16-bit PCM mono
  final pcmData = Int16List(numSamples);

  // 4 notes: C5 (523.25), E5 (659.25), G5 (783.99), C6 (1046.50)
  final notes = [
    (0.0, 0.25, 523.25),
    (0.2, 0.45, 659.25),
    (0.4, 0.65, 783.99),
    (0.6, 1.20, 1046.50),
  ];

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    double sampleVal = 0.0;

    for (final note in notes) {
      final start = note.$1;
      final end = note.$2;
      final freq = note.$3;

      if (t >= start && t <= end) {
        final noteT = t - start;
        final noteLen = end - start;
        // Simple attack and decay envelope
        final attack = (noteT / 0.03).clamp(0.0, 1.0);
        final decay = ((end - t) / (noteLen * 0.8)).clamp(0.0, 1.0);
        final env = attack * decay;
        // Fundamental + soft overtone
        final wave = sin(2 * pi * freq * t) + 0.3 * sin(2 * pi * freq * 2 * t);
        sampleVal += wave * env * 0.4;
      }
    }

    final clamped = (sampleVal * 32767).clamp(-32768, 32767).toInt();
    pcmData[i] = clamped;
  }

  // RIFF WAV Header
  final byteData = ByteData(44 + numSamples * 2);
  void writeString(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      byteData.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  byteData.setUint32(4, 36 + numSamples * 2, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
  byteData.setUint16(20, 1, Endian.little); // AudioFormat 1 = PCM
  byteData.setUint16(22, 1, Endian.little); // NumChannels 1
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
  byteData.setUint16(32, 2, Endian.little); // BlockAlign
  byteData.setUint16(34, 16, Endian.little); // BitsPerSample
  writeString(36, 'data');
  byteData.setUint32(40, numSamples * 2, Endian.little);

  for (int i = 0; i < numSamples; i++) {
    byteData.setInt16(44 + i * 2, pcmData[i], Endian.little);
  }

  final dir = Directory('assets/audio');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final file = File('assets/audio/game_over.wav');
  file.writeAsBytesSync(byteData.buffer.asUint8List());
  print('Generated ${file.path} with size ${file.lengthSync()} bytes');
}
