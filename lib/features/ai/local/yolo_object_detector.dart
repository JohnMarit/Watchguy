import 'dart:typed_data';

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'object_detector.dart';

/// YOLO26n through the Ultralytics plugin: LiteRT on Android, Core ML on iOS.
/// The model downloads on first use. If it cannot load, [isReady] stays false
/// and the caller should use the motion detector.
class YoloObjectDetector implements ObjectDetector {
  YoloObjectDetector({this.modelId = 'yolo26n'});

  final String modelId;
  YOLO? _yolo;
  var _ready = false;
  var _unavailable = false;

  bool get isReady => _ready;
  bool get unavailable => _unavailable;

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async {
    if (_unavailable) return const [];
    final jpeg = frame.jpeg;
    if (jpeg == null || jpeg.isEmpty) return const [];
    try {
      final yolo = _yolo ?? YOLO(modelPath: modelId, task: YOLOTask.detect);
      _yolo = yolo;
      if (!_ready) {
        _ready = await yolo.loadModel();
        if (!_ready) {
          _unavailable = true;
          return const [];
        }
      }
      final results = await yolo.predict(Uint8List.fromList(jpeg), confidenceThreshold: 0.35);
      final raw = results['detections'];
      if (raw is! List) return const [];
      return raw.whereType<Map>().map((item) {
        final result = YOLOResult.fromMap(Map<dynamic, dynamic>.from(item));
        final box = result.normalizedBox;
        return Detection(
          label: result.className,
          confidence: result.confidence,
          source: 'yolo26n',
          box: NormRect(left: box.left, top: box.top, width: box.width, height: box.height),
        );
      }).toList();
    } catch (_) {
      _unavailable = true;
      return const [];
    }
  }

  @override
  String get name => modelId;

  @override
  Future<void> dispose() async {
    _yolo = null;
    _ready = false;
  }
}

class FallbackDetector implements ObjectDetector {
  FallbackDetector({required this.primary, required this.fallback});

  final YoloObjectDetector primary;
  final ObjectDetector fallback;

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async {
    if (!primary.unavailable) {
      final found = await primary.detect(frame);
      if (primary.isReady) return found;
    }
    return fallback.detect(frame);
  }

  @override
  String get name => primary.isReady ? primary.name : fallback.name;

  @override
  Future<void> dispose() async {
    await primary.dispose();
    await fallback.dispose();
  }
}
