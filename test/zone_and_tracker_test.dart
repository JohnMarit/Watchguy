import 'package:flutter_test/flutter_test.dart';
import 'package:watchguy/core/models/enums.dart';
import 'package:watchguy/features/ai/local/object_detector.dart';
import 'package:watchguy/features/ai/local/object_tracker.dart';
import 'package:watchguy/features/ai/local/zone_detector.dart';
import 'package:watchguy/features/zones/domain/zone_geometry.dart';

void main() {
  final zone = SecurityZone(
    id: 'z1',
    organizationId: 'org',
    cameraId: 'cam',
    name: 'Rear door',
    type: ZoneType.restricted,
    createdAt: DateTime.utc(2026),
    points: const [
      NormPoint(0.1, 0.1),
      NormPoint(0.9, 0.1),
      NormPoint(0.9, 0.9),
      NormPoint(0.1, 0.9),
    ],
  );

  test('normalized polygons contain the feet of a person and ignore the outside', () {
    expect(pointInPolygon(const NormPoint(0.5, 0.5), zone.points), isTrue);
    expect(pointInPolygon(const NormPoint(0.05, 0.05), zone.points), isFalse);
    final detector = ZoneDetector();
    final inside = Track(
      id: 't1',
      label: 'person',
      box: const NormRect(left: 0.4, top: 0.2, width: 0.2, height: 0.4),
      firstSeen: DateTime.utc(2026, 1, 1, 2),
      lastSeen: DateTime.utc(2026, 1, 1, 2),
    );
    final entered = detector.observe(
      tracks: [inside],
      zones: [zone],
      now: DateTime.utc(2026, 1, 1, 2),
      loiterAfter: const Duration(seconds: 30),
    );
    expect(entered.restrictedOccupied, isTrue);
    final left = detector.observe(
      tracks: [
        Track(
          id: 't2',
          label: 'person',
          box: const NormRect(left: 0, top: 0, width: 0.05, height: 0.05),
          firstSeen: DateTime.utc(2026, 1, 1, 2),
          lastSeen: DateTime.utc(2026, 1, 1, 2),
        ),
      ],
      zones: [zone],
      now: DateTime.utc(2026, 1, 1, 2, 0, 1),
      loiterAfter: const Duration(seconds: 30),
    );
    expect(left.restrictedOccupied, isFalse);
  });

  test('tracker keeps an id while a person stays in frame', () {
    final tracker = ObjectTracker();
    final now = DateTime.utc(2026, 1, 1);
    final first = tracker.update([
      const Detection(label: 'person', confidence: 0.9, box: NormRect(left: 0.2, top: 0.2, width: 0.2, height: 0.4)),
    ], now);
    final second = tracker.update([
      const Detection(label: 'person', confidence: 0.9, box: NormRect(left: 0.22, top: 0.2, width: 0.2, height: 0.4)),
    ], now.add(const Duration(milliseconds: 200)));
    expect(second.single.id, first.single.id);
  });
}
