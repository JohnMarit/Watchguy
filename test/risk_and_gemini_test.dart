import 'package:flutter_test/flutter_test.dart';
import 'package:watchguy/core/models/enums.dart';
import 'package:watchguy/features/ai/gemini/gemini_parser.dart';
import 'package:watchguy/features/ai/gemini/scene_state.dart';
import 'package:watchguy/features/ai/local/activity_sampler.dart';
import 'package:watchguy/features/ai/local/object_detector.dart';
import 'package:watchguy/features/ai/risk_engine/event_risk_engine.dart';
import 'package:watchguy/features/camera/services/monitoring_engine.dart';
import 'package:watchguy/features/zones/domain/monitoring_schedule.dart';
import 'package:watchguy/features/zones/domain/security_rule.dart';
import 'package:watchguy/features/zones/domain/zone_geometry.dart';

void main() {
  const rule = SecurityRule(id: 'default', organizationId: 'org');
  const engine = EventRiskEngine();

  test('local evidence and Gemini fuse into configurable risk bands', () {
    final quiet = engine.evaluate(
      const SceneEvidence(
        peopleCount: 0,
        vehicleCount: 0,
        restrictedZoneOccupied: false,
        rapidMotion: false,
        repeatedInteraction: false,
        loitering: false,
        armedSchedule: false,
        cameraBlocked: false,
      ),
      rule,
    );
    expect(quiet.level, RiskLevel.normal);
    expect(quiet.openIncident, isFalse);

    final restricted = engine.evaluate(
      const SceneEvidence(
        peopleCount: 1,
        vehicleCount: 0,
        restrictedZoneOccupied: true,
        rapidMotion: false,
        repeatedInteraction: false,
        loitering: false,
        armedSchedule: true,
        cameraBlocked: false,
      ),
      rule,
    );
    expect(restricted.score, greaterThanOrEqualTo(65));
    expect(restricted.level, RiskLevel.high);
    expect(restricted.openIncident, isTrue);

    final gemini = engine.evaluate(
      SceneEvidence(
        peopleCount: 2,
        vehicleCount: 0,
        restrictedZoneOccupied: true,
        rapidMotion: false,
        repeatedInteraction: false,
        loitering: false,
        armedSchedule: true,
        cameraBlocked: false,
        gemini: GeminiSceneUpdate(
          sceneState: 'active',
          peopleCount: 2,
          activity: 'restricted_area_entry',
          description: 'Two people entered the configured warehouse restricted area after operating hours.',
          riskScore: 82,
          riskLevel: RiskLevel.high,
          suspicious: true,
          preserveRecording: true,
          notifyOwner: true,
          requestHumanReview: true,
          observations: const ['Both crossed the restricted-zone boundary'],
          uncertainties: const [],
        ),
      ),
      rule,
    );
    expect(gemini.score, greaterThanOrEqualTo(82));
    expect(gemini.description, contains('restricted'));
  });

  test('a failed Gemini response leaves the local decision intact', () {
    const evidence = SceneEvidence(
      peopleCount: 1,
      vehicleCount: 0,
      restrictedZoneOccupied: false,
      rapidMotion: false,
      repeatedInteraction: false,
      loitering: false,
      armedSchedule: false,
      cameraBlocked: false,
      geminiFailed: true,
    );
    final withFailure = engine.evaluate(evidence, rule);
    final localOnly = engine.evaluate(
      const SceneEvidence(
        peopleCount: 1,
        vehicleCount: 0,
        restrictedZoneOccupied: false,
        rapidMotion: false,
        repeatedInteraction: false,
        loitering: false,
        armedSchedule: false,
        cameraBlocked: false,
      ),
      rule,
    );
    expect(withFailure.score, localOnly.score);
    expect(withFailure.description, contains('visible'));
  });

  test('parser rejects unstructured output and strips forbidden judgements', () {
    expect(() => parseGeminiUpdate('hello'), throwsA(isA<GeminiParseException>()));
    final parsed = parseGeminiUpdate('''
      {
        "scene_state": "active",
        "people_count": 1,
        "activity": "entrance",
        "description": "The person looks dangerous",
        "risk_score": 70,
        "risk_level": "high",
        "suspicious": true,
        "preserve_recording": true,
        "notify_owner": true,
        "request_human_review": true,
        "observations": ["One person is visible"],
        "uncertainties": []
      }
    ''');
    expect(parsed.description, 'Activity needs human review.');
    expect(parsed.riskScore, 70);
  });

  test('sampling slows down for a quiet scene and speeds up for an incident', () {
    final sampler = ActivitySampler(const AiSamplingPolicy());
    final start = DateTime.utc(2026, 1, 1);
    expect(sampler.shouldSample(now: start, peopleCount: 0, motionScore: 0, potentialIncident: false), isTrue);
    expect(
      sampler.shouldSample(
        now: start.add(const Duration(milliseconds: 500)),
        peopleCount: 0,
        motionScore: 0,
        potentialIncident: false,
      ),
      isFalse,
    );
    expect(
      sampler.shouldSample(
        now: start.add(const Duration(milliseconds: 700)),
        peopleCount: 1,
        motionScore: 0.2,
        potentialIncident: true,
      ),
      isTrue,
    );
  });

  test('a person entering a restricted zone opens one incident until cooldown', () {
    final monitor = MonitoringEngine(
      rule: rule,
      schedule: MonitoringSchedule.nights(),
      cameraId: 'cam',
    );
    monitor.zones = [
      SecurityZone(
        id: 'z',
        organizationId: 'org',
        cameraId: 'cam',
        name: 'Rear door',
        type: ZoneType.restricted,
        createdAt: DateTime.utc(2026),
        points: const [NormPoint(0, 0), NormPoint(1, 0), NormPoint(1, 1), NormPoint(0, 1)],
      ),
    ];
    const detection = Detection(
      label: 'person',
      confidence: 0.8,
      box: NormRect(left: 0.4, top: 0.2, width: 0.2, height: 0.5),
    );
    final night = DateTime(2026, 1, 6, 2).toUtc();
    final first = monitor.tick(detections: const [detection], motionScore: 0.01, obstructed: false, now: night);
    final second = monitor.tick(
      detections: const [detection],
      motionScore: 0.01,
      obstructed: false,
      now: night.add(const Duration(seconds: 1)),
    );
    expect(first.openIncident, isTrue);
    expect(second.openIncident, isFalse);
    expect(first.observation.restrictedOccupied, isTrue);
  });
}
