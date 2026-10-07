import '../../../core/models/enums.dart';

const forbiddenJudgements = [
  'criminal',
  'evil',
  'malicious',
  'dangerous',
  'guilty',
];

class SceneState {
  const SceneState({
    required this.cameraId,
    required this.peopleCount,
    required this.activity,
    required this.riskScore,
    required this.riskLevel,
    required this.restrictedZoneOccupied,
    this.description = '',
  });

  final String cameraId;
  final int peopleCount;
  final String activity;
  final int riskScore;
  final RiskLevel riskLevel;
  final bool restrictedZoneOccupied;
  final String description;

  Map<String, dynamic> toJson() => {
        'camera_id': cameraId,
        'people_count': peopleCount,
        'activity': activity,
        'risk_score': riskScore,
        'risk_level': riskLevel.name,
        'restricted_zone_occupied': restrictedZoneOccupied,
        'description': description,
      };

  SceneState copyWith({
    int? peopleCount,
    String? activity,
    int? riskScore,
    RiskLevel? riskLevel,
    bool? restrictedZoneOccupied,
    String? description,
  }) {
    return SceneState(
      cameraId: cameraId,
      peopleCount: peopleCount ?? this.peopleCount,
      activity: activity ?? this.activity,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      restrictedZoneOccupied: restrictedZoneOccupied ?? this.restrictedZoneOccupied,
      description: description ?? this.description,
    );
  }
}

class GeminiSceneUpdate {
  const GeminiSceneUpdate({
    required this.sceneState,
    required this.peopleCount,
    required this.activity,
    required this.description,
    required this.riskScore,
    required this.riskLevel,
    required this.suspicious,
    required this.preserveRecording,
    required this.notifyOwner,
    required this.requestHumanReview,
    required this.observations,
    required this.uncertainties,
  });

  final String sceneState;
  final int peopleCount;
  final String activity;
  final String description;
  final int riskScore;
  final RiskLevel riskLevel;
  final bool suspicious;
  final bool preserveRecording;
  final bool notifyOwner;
  final bool requestHumanReview;
  final List<String> observations;
  final List<String> uncertainties;

  Map<String, dynamic> toJson() => {
        'scene_state': sceneState,
        'people_count': peopleCount,
        'activity': activity,
        'description': description,
        'risk_score': riskScore,
        'risk_level': riskLevel.name,
        'suspicious': suspicious,
        'preserve_recording': preserveRecording,
        'notify_owner': notifyOwner,
        'request_human_review': requestHumanReview,
        'observations': observations,
        'uncertainties': uncertainties,
      };
}
