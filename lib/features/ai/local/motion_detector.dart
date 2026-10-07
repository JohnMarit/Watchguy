import 'dart:math';
import 'dart:typed_data';

class MotionSample {
  const MotionSample({required this.score, required this.obstructed});

  final double score;
  final bool obstructed;
}

class MotionDetector {
  Uint8List? _previous;
  int _stillFrames = 0;

  MotionSample sample(Uint8List gray) {
    final variance = _variance(gray);
    final obstructed = variance < 12;
    if (_previous == null || _previous!.length != gray.length) {
      _previous = Uint8List.fromList(gray);
      return MotionSample(score: 0, obstructed: obstructed);
    }
    var diff = 0;
    for (var i = 0; i < gray.length; i++) {
      diff += (gray[i] - _previous![i]).abs();
    }
    _previous = Uint8List.fromList(gray);
    final score = (diff / (gray.length * 255)).clamp(0.0, 1.0);
    if (score < 0.01) {
      _stillFrames += 1;
    } else {
      _stillFrames = 0;
    }
    return MotionSample(
      score: score,
      obstructed: obstructed || _stillFrames > 40,
    );
  }

  double _variance(Uint8List gray) {
    if (gray.isEmpty) return 0;
    var sum = 0;
    for (final value in gray) {
      sum += value;
    }
    final mean = sum / gray.length;
    var accum = 0.0;
    for (final value in gray) {
      final delta = value - mean;
      accum += delta * delta;
    }
    return sqrt(accum / gray.length);
  }

  void reset() {
    _previous = null;
    _stillFrames = 0;
  }
}
