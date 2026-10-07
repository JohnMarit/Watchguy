import 'package:flutter_test/flutter_test.dart';
import 'package:watchguy/features/ai/local/object_detector.dart';
import 'package:watchguy/features/ai/local/scene_narration.dart';
import 'package:watchguy/features/ai/local/zone_detector.dart';
import 'package:watchguy/features/zones/domain/zone_geometry.dart';
import 'package:watchguy/core/models/enums.dart';

void main() {
  const box = NormRect(left: 0.2, top: 0.2, width: 0.3, height: 0.5);

  test('a still person is described without becoming the only thing that can be said', () {
    final standing = describeScene(
      detections: const [Detection(label: 'person', confidence: 0.9, box: box)],
      motionScore: 0,
    );
    expect(standing, 'A person is standing in view.');

    final moving = describeScene(
      detections: const [Detection(label: 'person', confidence: 0.9, box: box)],
      motionScore: 0.08,
    );
    expect(moving, 'A person is moving in view.');

    final dog = describeScene(
      detections: const [Detection(label: 'dog', confidence: 0.8, box: box)],
      motionScore: 0.04,
    );
    expect(dog, 'A dog is in view.');

    final mixed = describeScene(
      detections: const [
        Detection(label: 'person', confidence: 0.9, box: box),
        Detection(label: 'backpack', confidence: 0.7, box: box),
      ],
      motionScore: 0,
    );
    expect(mixed, 'A person and a backpack are in view.');
    expect(describeScene(detections: const [], motionScore: 0), 'Nothing is happening in view.');
  });

  test('an animal in a restricted zone is described and does not open a zone incident', () {
    final observation = ZoneDetector().observe(
      tracks: [
        Track(
          id: 'dog',
          label: 'dog',
          box: box,
          firstSeen: DateTime.utc(2026, 10, 5),
          lastSeen: DateTime.utc(2026, 10, 5),
        ),
      ],
      zones: [
        SecurityZone(
          id: 'gate',
          organizationId: 'org',
          cameraId: 'cam',
          name: 'After-hours gate',
          type: ZoneType.restricted,
          points: const [NormPoint(0, 0), NormPoint(1, 0), NormPoint(1, 1), NormPoint(0, 1)],
          createdAt: DateTime.utc(2026, 10, 5),
        ),
      ],
      now: DateTime.utc(2026, 10, 5),
      loiterAfter: const Duration(seconds: 20),
    );
    expect(observation.restrictedOccupied, isFalse);
    expect(observation.peopleCount, 0);
  });
}
