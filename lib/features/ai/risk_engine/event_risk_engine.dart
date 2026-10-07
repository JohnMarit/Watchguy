import '../../../core/models/enums.dart';
import '../../zones/domain/security_rule.dart';
import '../gemini/scene_state.dart';

class SceneEvidence {
  const SceneEvidence({
    required this.peopleCount,
    required this.vehicleCount,
    required this.restrictedZoneOccupied,
    required this.rapidMotion,
    required this.repeatedInteraction,
    required this.loitering,
    required this.armedSchedule,
    required this.cameraBlocked,
    this.gemini,
    this.geminiFailed = false,
  });

  final int peopleCount;
  final int vehicleCount;
  final bool restrictedZoneOccupied;
  final bool rapidMotion;
  final bool repeatedInteraction;
  final bool loitering;
  final bool armedSchedule;
  final bool cameraBlocked;
  final GeminiSceneUpdate? gemini;
  final bool geminiFailed;
}

class RiskDecision {
  const RiskDecision({
    required this.localScore,
    required this.score,
    required this.level,
    required this.openIncident,
    required this.description,
    required this.observations,
  });

  final int localScore;
  final int score;
  final RiskLevel level;
  final bool openIncident;
  final String description;
  final List<String> observations;
}

class LocalRiskEngine {
  const LocalRiskEngine();

  int score(SceneEvidence evidence, SecurityRule rule) {
    var total = 0;
    if (evidence.peopleCount > 0) total += rule.personPoints;
    if (evidence.vehicleCount > 0) total += rule.personPoints;
    if (evidence.restrictedZoneOccupied) total += rule.restrictedZonePoints;
    if (evidence.armedSchedule && (evidence.peopleCount > 0 || evidence.restrictedZoneOccupied)) {
      total += rule.afterHoursPoints;
    }
    if (evidence.rapidMotion) total += rule.rapidMotionPoints;
    if (evidence.repeatedInteraction) total += rule.repeatedInteractionPoints;
    if (evidence.loitering) total += rule.loiteringPoints;
    if (evidence.cameraBlocked) total += rule.obstructionPoints;
    return total.clamp(0, 100);
  }
}

class EventRiskEngine {
  const EventRiskEngine({this.local = const LocalRiskEngine()});

  final LocalRiskEngine local;

  RiskDecision evaluate(SceneEvidence evidence, SecurityRule rule) {
    final localScore = local.score(evidence, rule);
    final gemini = evidence.gemini;
    var fused = localScore;
    if (gemini != null && !evidence.geminiFailed) {
      if (gemini.suspicious || gemini.requestHumanReview || gemini.preserveRecording) {
        final bumped = localScore + rule.geminiIncidentPoints;
        fused = bumped > gemini.riskScore ? bumped : gemini.riskScore;
      } else {
        final delta = ((gemini.riskScore - localScore) * 0.25).round();
        fused = localScore + delta;
      }
    }
    fused = fused.clamp(0, 100);
    final level = rule.bands.levelFor(fused);
    final observations = <String>[
      if (evidence.peopleCount > 0) '${evidence.peopleCount} people are visible',
      if (evidence.restrictedZoneOccupied) 'A person is inside a restricted zone',
      if (evidence.armedSchedule && evidence.peopleCount > 0)
        'The monitoring schedule marks this time as armed',
      if (evidence.rapidMotion) 'Motion increased quickly',
      if (evidence.repeatedInteraction) 'Repeated interaction at an entrance',
      if (evidence.loitering) 'A person has remained in a zone',
      if (evidence.cameraBlocked) 'The camera view looks obstructed',
      ...?gemini?.observations,
    ];
    final description = gemini == null || evidence.geminiFailed
        ? _localDescription(evidence)
        : gemini.description;
    final triggered = fused >= rule.incidentThreshold ||
        (gemini?.preserveRecording == true &&
            (evidence.peopleCount > 0 ||
                evidence.restrictedZoneOccupied ||
                evidence.rapidMotion ||
                evidence.cameraBlocked));
    return RiskDecision(
      localScore: localScore,
      score: fused,
      level: level,
      openIncident: triggered,
      description: description,
      observations: observations,
    );
  }

  String _localDescription(SceneEvidence evidence) {
    if (evidence.cameraBlocked) return 'The camera view appears blocked.';
    if (evidence.restrictedZoneOccupied && evidence.armedSchedule) {
      return 'A person entered a restricted zone while the schedule is armed.';
    }
    if (evidence.restrictedZoneOccupied) {
      return 'A person entered a restricted zone.';
    }
    if (evidence.peopleCount > 0) {
      return '${evidence.peopleCount == 1 ? 'One person is' : '${evidence.peopleCount} people are'} visible.';
    }
    return 'The scene is quiet.';
  }
}

class IncidentLatch {
  DateTime? _openUntil;

  bool shouldOpen({
    required bool triggered,
    required DateTime now,
    required Duration cooldown,
  }) {
    final openUntil = _openUntil;
    if (openUntil != null && now.isBefore(openUntil)) return false;
    if (!triggered) {
      _openUntil = null;
      return false;
    }
    _openUntil = now.add(cooldown);
    return true;
  }
}
