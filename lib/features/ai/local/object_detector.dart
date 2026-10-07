import '../../zones/domain/zone_geometry.dart';

class Detection {
  const Detection({
    required this.label,
    required this.confidence,
    required this.box,
    this.source = 'detector',
  });

  final String label;
  final double confidence;
  final NormRect box;
  final String source;

  bool get isPerson => label == 'person';
  bool get isVehicle => isSecurityVehicle(label);

  NormPoint get feet {
    return NormPoint(box.left + box.width / 2, box.top + box.height);
  }
}

bool isSecurityVehicle(String label) {
  return label == 'car' || label == 'truck' || label == 'bus' || label == 'motorcycle';
}

bool isSecuritySubject(String label) {
  return label == 'person' || isSecurityVehicle(label);
}

class NormRect {
  const NormRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double iou(NormRect other) {
    final x1 = left > other.left ? left : other.left;
    final y1 = top > other.top ? top : other.top;
    final x2 = (left + width) < (other.left + other.width)
        ? left + width
        : other.left + other.width;
    final y2 = (top + height) < (other.top + other.height)
        ? top + height
        : other.top + other.height;
    final w = x2 - x1;
    final h = y2 - y1;
    if (w <= 0 || h <= 0) return 0;
    final intersection = w * h;
    final union = width * height + other.width * other.height - intersection;
    if (union <= 0) return 0;
    return intersection / union;
  }
}

class Track {
  Track({
    required this.id,
    required this.label,
    required this.box,
    required this.firstSeen,
    required this.lastSeen,
    this.confidence = 0,
    this.missed = 0,
    this.zoneEntries = 0,
    this.insideZoneId,
    this.zoneEnteredAt,
  });

  final String id;
  String label;
  NormRect box;
  final DateTime firstSeen;
  DateTime lastSeen;
  double confidence;
  int missed;
  int zoneEntries;
  String? insideZoneId;
  DateTime? zoneEnteredAt;

  NormPoint get feet => NormPoint(box.left + box.width / 2, box.top + box.height);

  Duration ageAt(DateTime now) => now.difference(firstSeen);
}

abstract class ObjectDetector {
  Future<List<Detection>> detect(DetectorFrame frame);
  String get name => 'local ai';
  Future<void> dispose() async {}
}

class DetectorFrame {
  const DetectorFrame({
    required this.bytes,
    required this.width,
    required this.height,
    this.jpeg,
  });

  final List<int> bytes;
  final int width;
  final int height;
  final List<int>? jpeg;
}

class FakeObjectDetector implements ObjectDetector {
  FakeObjectDetector(this.detections);

  List<Detection> detections;

  @override
  Future<List<Detection>> detect(DetectorFrame frame) async => detections;

  @override
  String get name => 'fake';

  @override
  Future<void> dispose() async {}
}
