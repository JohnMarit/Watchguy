import 'dart:typed_data';

import 'object_detector.dart';
import 'scene_narration.dart';

/// Motion regions used while an object model is still downloading. The shape is
/// not named as a person: only the object model may claim what something is.
class MotionBlobDetector implements ObjectDetector {
  Uint8List? _previous;

  @override
  String get name => 'motion';

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async {
    final gray = Uint8List.fromList(frame.bytes);
    final previous = _previous;
    _previous = Uint8List.fromList(gray);
    if (previous == null || previous.length != gray.length) return const [];
    const columns = 6;
    const rows = 4;
    final cellW = frame.width ~/ columns;
    final cellH = frame.height ~/ rows;
    if (cellW == 0 || cellH == 0) return const [];
    final active = <bool>[];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        var diff = 0;
        var count = 0;
        for (var y = row * cellH; y < (row + 1) * cellH; y += 2) {
          for (var x = column * cellW; x < (column + 1) * cellW; x += 2) {
            final index = y * frame.width + x;
            diff += (gray[index] - previous[index]).abs();
            count += 1;
          }
        }
        active.add(count > 0 && diff / count > 18);
      }
    }
    var minCol = columns;
    var maxCol = -1;
    var minRow = rows;
    var maxRow = -1;
    var hits = 0;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        if (!active[row * columns + column]) continue;
        hits += 1;
        if (column < minCol) minCol = column;
        if (column > maxCol) maxCol = column;
        if (row < minRow) minRow = row;
        if (row > maxRow) maxRow = row;
      }
    }
    if (hits < 2) return const [];
    final height = (maxRow - minRow + 1) / rows;
    final width = (maxCol - minCol + 1) / columns;
    if (height < 0.4 || width > 0.8) return const [];
    return [
      Detection(
        label: movingObjectLabel,
        confidence: 0.42,
        source: 'motion',
        box: NormRect(
          left: minCol / columns,
          top: minRow / rows,
          width: width,
          height: height,
        ),
      ),
    ];
  }

  @override
  Future<void> dispose() async {}
}
