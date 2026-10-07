import '../../../core/models/enums.dart';

class RiskBands {
  const RiskBands({
    this.low = 25,
    this.medium = 45,
    this.high = 65,
    this.critical = 85,
  });

  final int low;
  final int medium;
  final int high;
  final int critical;

  RiskLevel levelFor(int score) {
    final clamped = score.clamp(0, 100);
    if (clamped >= critical) return RiskLevel.critical;
    if (clamped >= high) return RiskLevel.high;
    if (clamped >= medium) return RiskLevel.medium;
    if (clamped >= low) return RiskLevel.low;
    return RiskLevel.normal;
  }

  Map<String, dynamic> toJson() => {
        'low': low,
        'medium': medium,
        'high': high,
        'critical': critical,
      };

  factory RiskBands.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RiskBands();
    return RiskBands(
      low: (json['low'] as num?)?.toInt() ?? 25,
      medium: (json['medium'] as num?)?.toInt() ?? 45,
      high: (json['high'] as num?)?.toInt() ?? 65,
      critical: (json['critical'] as num?)?.toInt() ?? 85,
    );
  }
}

class SecurityRule {
  const SecurityRule({
    required this.id,
    required this.organizationId,
    this.cameraId,
    this.personPoints = 8,
    this.restrictedZonePoints = 35,
    this.afterHoursPoints = 25,
    this.rapidMotionPoints = 15,
    this.repeatedInteractionPoints = 20,
    this.loiteringPoints = 20,
    this.obstructionPoints = 30,
    this.geminiIncidentPoints = 40,
    this.incidentThreshold = 65,
    this.loiteringSeconds = 30,
    this.preRollSeconds = 10,
    this.postRollSeconds = 20,
    this.incidentCooldownSeconds = 60,
    this.bands = const RiskBands(),
  });

  final String id;
  final String organizationId;
  final String? cameraId;
  final int personPoints;
  final int restrictedZonePoints;
  final int afterHoursPoints;
  final int rapidMotionPoints;
  final int repeatedInteractionPoints;
  final int loiteringPoints;
  final int obstructionPoints;
  final int geminiIncidentPoints;
  final int incidentThreshold;
  final int loiteringSeconds;
  final int preRollSeconds;
  final int postRollSeconds;
  final int incidentCooldownSeconds;
  final RiskBands bands;

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationId': organizationId,
        'cameraId': cameraId,
        'personPoints': personPoints,
        'restrictedZonePoints': restrictedZonePoints,
        'afterHoursPoints': afterHoursPoints,
        'rapidMotionPoints': rapidMotionPoints,
        'repeatedInteractionPoints': repeatedInteractionPoints,
        'loiteringPoints': loiteringPoints,
        'obstructionPoints': obstructionPoints,
        'geminiIncidentPoints': geminiIncidentPoints,
        'incidentThreshold': incidentThreshold,
        'loiteringSeconds': loiteringSeconds,
        'preRollSeconds': preRollSeconds,
        'postRollSeconds': postRollSeconds,
        'incidentCooldownSeconds': incidentCooldownSeconds,
        'bands': bands.toJson(),
      };

  factory SecurityRule.fromJson(Map<String, dynamic> json) {
    return SecurityRule(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      cameraId: json['cameraId'] as String?,
      personPoints: (json['personPoints'] as num?)?.toInt() ?? 8,
      restrictedZonePoints: (json['restrictedZonePoints'] as num?)?.toInt() ?? 35,
      afterHoursPoints: (json['afterHoursPoints'] as num?)?.toInt() ?? 25,
      rapidMotionPoints: (json['rapidMotionPoints'] as num?)?.toInt() ?? 15,
      repeatedInteractionPoints:
          (json['repeatedInteractionPoints'] as num?)?.toInt() ?? 20,
      loiteringPoints: (json['loiteringPoints'] as num?)?.toInt() ?? 20,
      obstructionPoints: (json['obstructionPoints'] as num?)?.toInt() ?? 30,
      geminiIncidentPoints: (json['geminiIncidentPoints'] as num?)?.toInt() ?? 40,
      incidentThreshold: (json['incidentThreshold'] as num?)?.toInt() ?? 65,
      loiteringSeconds: (json['loiteringSeconds'] as num?)?.toInt() ?? 30,
      preRollSeconds: (json['preRollSeconds'] as num?)?.toInt() ?? 10,
      postRollSeconds: (json['postRollSeconds'] as num?)?.toInt() ?? 20,
      incidentCooldownSeconds:
          (json['incidentCooldownSeconds'] as num?)?.toInt() ?? 60,
      bands: RiskBands.fromJson(json['bands'] as Map<String, dynamic>?),
    );
  }

  static SecurityRule defaults(String organizationId) {
    return SecurityRule(id: 'default', organizationId: organizationId);
  }
}
