import '../../../core/models/enums.dart';
import '../../../core/time/json_time.dart';

class Incident {
  const Incident({
    required this.id,
    required this.organizationId,
    required this.cameraId,
    required this.cameraName,
    required this.createdAt,
    required this.eventStart,
    required this.eventEnd,
    required this.riskLevel,
    required this.riskScore,
    required this.eventType,
    required this.description,
    required this.observations,
    required this.aiConfidence,
    required this.status,
    required this.reviewState,
    required this.createdByEngine,
    this.thumbnailUrl,
    this.videoUrl,
    this.zoneName,
    this.localClipPath,
  });

  final String id;
  final String organizationId;
  final String cameraId;
  final String cameraName;
  final DateTime createdAt;
  final DateTime eventStart;
  final DateTime eventEnd;
  final RiskLevel riskLevel;
  final int riskScore;
  final String eventType;
  final String description;
  final List<String> observations;
  final double aiConfidence;
  final IncidentStatus status;
  final ReviewState reviewState;
  final String createdByEngine;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? zoneName;
  final String? localClipPath;

  Incident copyWith({
    IncidentStatus? status,
    ReviewState? reviewState,
    String? thumbnailUrl,
    String? videoUrl,
    String? localClipPath,
    DateTime? eventEnd,
  }) {
    return Incident(
      id: id,
      organizationId: organizationId,
      cameraId: cameraId,
      cameraName: cameraName,
      createdAt: createdAt,
      eventStart: eventStart,
      eventEnd: eventEnd ?? this.eventEnd,
      riskLevel: riskLevel,
      riskScore: riskScore,
      eventType: eventType,
      description: description,
      observations: observations,
      aiConfidence: aiConfidence,
      status: status ?? this.status,
      reviewState: reviewState ?? this.reviewState,
      createdByEngine: createdByEngine,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      zoneName: zoneName,
      localClipPath: localClipPath ?? this.localClipPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationId': organizationId,
        'cameraId': cameraId,
        'cameraName': cameraName,
        'createdAt': writeTime(createdAt),
        'eventStart': writeTime(eventStart),
        'eventEnd': writeTime(eventEnd),
        'riskLevel': riskLevel.name,
        'riskScore': riskScore,
        'eventType': eventType,
        'description': description,
        'observations': observations,
        'aiConfidence': aiConfidence,
        'status': status.name,
        'reviewState': reviewState.name,
        'createdByEngine': createdByEngine,
        'thumbnailUrl': thumbnailUrl,
        'videoUrl': videoUrl,
        'zoneName': zoneName,
        'localClipPath': localClipPath,
      };

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      cameraId: json['cameraId'] as String,
      cameraName: json['cameraName'] as String? ?? '',
      createdAt: parseTime(json['createdAt']),
      eventStart: parseTime(json['eventStart']),
      eventEnd: parseTime(json['eventEnd']),
      riskLevel: enumByName(RiskLevel.values, json['riskLevel'], RiskLevel.normal),
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      eventType: json['eventType'] as String? ?? 'activity',
      description: json['description'] as String? ?? '',
      observations: (json['observations'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
      aiConfidence: (json['aiConfidence'] as num?)?.toDouble() ?? 0,
      status: enumByName(IncidentStatus.values, json['status'], IncidentStatus.detected),
      reviewState: enumByName(ReviewState.values, json['reviewState'], ReviewState.unreviewed),
      createdByEngine: json['createdByEngine'] as String? ?? 'event_risk_engine',
      thumbnailUrl: json['thumbnailUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      zoneName: json['zoneName'] as String?,
      localClipPath: json['localClipPath'] as String?,
    );
  }
}

bool shouldNotifyRisk(RiskLevel level) {
  return level == RiskLevel.high || level == RiskLevel.critical;
}
