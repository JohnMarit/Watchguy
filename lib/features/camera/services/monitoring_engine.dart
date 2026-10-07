import '../../ai/gemini/scene_state.dart';
import '../../ai/local/object_detector.dart';
import '../../ai/local/object_tracker.dart';
import '../../ai/local/zone_detector.dart';
import '../../ai/risk_engine/event_risk_engine.dart';
import '../../zones/domain/monitoring_schedule.dart';
import '../../zones/domain/security_rule.dart';
import '../../zones/domain/zone_geometry.dart';

class MonitoringSnapshot {
  const MonitoringSnapshot({
    required this.peopleCount,
    required this.vehicleCount,
    required this.decision,
    required this.observation,
    required this.openIncident,
    required this.scene,
  });

  final int peopleCount;
  final int vehicleCount;
  final RiskDecision decision;
  final ZoneObservation observation;
  final bool openIncident;
  final SceneState scene;
}

class MonitoringEngine {
  MonitoringEngine({
    required this.rule,
    required this.schedule,
    required this.cameraId,
    ObjectTracker? tracker,
    ZoneDetector? zoneDetector,
    EventRiskEngine? riskEngine,
    IncidentLatch? latch,
  })  : tracker = tracker ?? ObjectTracker(),
        zoneDetector = zoneDetector ?? ZoneDetector(),
        riskEngine = riskEngine ?? const EventRiskEngine(),
        latch = latch ?? IncidentLatch();

  final SecurityRule rule;
  final MonitoringSchedule schedule;
  final String cameraId;
  final ObjectTracker tracker;
  final ZoneDetector zoneDetector;
  final EventRiskEngine riskEngine;
  final IncidentLatch latch;
  List<SecurityZone> zones = const [];

  MonitoringSnapshot tick({
    required List<Detection> detections,
    required double motionScore,
    required bool obstructed,
    required DateTime now,
    GeminiSceneUpdate? gemini,
    bool geminiFailed = false,
  }) {
    final tracks = tracker.update(detections, now);
    final observation = zoneDetector.observe(
      tracks: tracks,
      zones: zones,
      now: now,
      loiterAfter: Duration(seconds: rule.loiteringSeconds),
    );
    final evidence = SceneEvidence(
      peopleCount: observation.peopleCount,
      vehicleCount: observation.vehicleCount,
      restrictedZoneOccupied: observation.restrictedOccupied,
      rapidMotion: motionScore >= 0.12,
      repeatedInteraction: observation.entranceInteractions >= 3,
      loitering: observation.loitering,
      armedSchedule: schedule.isArmed(now),
      cameraBlocked: obstructed,
      gemini: gemini,
      geminiFailed: geminiFailed,
    );
    final decision = riskEngine.evaluate(evidence, rule);
    final open = latch.shouldOpen(
      triggered: decision.openIncident,
      now: now,
      cooldown: Duration(seconds: rule.incidentCooldownSeconds),
    );
    return MonitoringSnapshot(
      peopleCount: observation.peopleCount,
      vehicleCount: observation.vehicleCount,
      decision: decision,
      observation: observation,
      openIncident: open,
      scene: SceneState(
        cameraId: cameraId,
        peopleCount: observation.peopleCount,
        activity: gemini?.activity ?? _activity(evidence),
        riskScore: decision.score,
        riskLevel: decision.level,
        restrictedZoneOccupied: observation.restrictedOccupied,
        description: decision.description,
      ),
    );
  }

  String _activity(SceneEvidence evidence) {
    if (evidence.restrictedZoneOccupied) return 'restricted_area_entry';
    if (evidence.peopleCount > 0) return 'people_present';
    if (evidence.cameraBlocked) return 'camera_obstructed';
    return 'quiet';
  }
}
