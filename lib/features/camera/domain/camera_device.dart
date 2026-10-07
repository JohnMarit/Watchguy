import '../../../core/models/enums.dart';
import '../../../core/time/json_time.dart';
import '../../zones/domain/monitoring_schedule.dart';

class DeviceHeartbeat {
  const DeviceHeartbeat({
    required this.operationalState,
    required this.aiStatus,
    required this.monitoredAt,
    required this.charging,
    required this.peopleCount,
    required this.riskLevel,
    required this.riskScore,
    required this.activity,
    required this.networkQuality,
    required this.cloudAiOnline,
    required this.cameraBlocked,
    this.batteryPercent,
  });

  final OperationalState operationalState;
  final AiStatus aiStatus;
  final DateTime monitoredAt;
  final bool charging;
  final int peopleCount;
  final RiskLevel riskLevel;
  final int riskScore;
  final String activity;
  final NetworkQuality networkQuality;
  final bool cloudAiOnline;
  final bool cameraBlocked;
  final int? batteryPercent;

  static DeviceHeartbeat idle(DateTime now) {
    return DeviceHeartbeat(
      operationalState: OperationalState.idle,
      aiStatus: AiStatus.idle,
      monitoredAt: now,
      charging: false,
      peopleCount: 0,
      riskLevel: RiskLevel.normal,
      riskScore: 0,
      activity: '',
      networkQuality: NetworkQuality.unknown,
      cloudAiOnline: false,
      cameraBlocked: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'operationalState': operationalState.name,
        'aiStatus': aiStatus.name,
        'monitoredAt': writeTime(monitoredAt),
        'charging': charging,
        'peopleCount': peopleCount,
        'riskLevel': riskLevel.name,
        'riskScore': riskScore,
        'activity': activity,
        'networkQuality': networkQuality.name,
        'cloudAiOnline': cloudAiOnline,
        'cameraBlocked': cameraBlocked,
        'batteryPercent': batteryPercent,
      };

  factory DeviceHeartbeat.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DeviceHeartbeat.idle(DateTime.now().toUtc());
    return DeviceHeartbeat(
      operationalState: enumByName(
        OperationalState.values,
        json['operationalState'],
        OperationalState.idle,
      ),
      aiStatus: enumByName(AiStatus.values, json['aiStatus'], AiStatus.idle),
      monitoredAt: parseTime(json['monitoredAt']),
      charging: json['charging'] as bool? ?? false,
      peopleCount: (json['peopleCount'] as num?)?.toInt() ?? 0,
      riskLevel: enumByName(RiskLevel.values, json['riskLevel'], RiskLevel.normal),
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      activity: json['activity'] as String? ?? '',
      networkQuality: enumByName(
        NetworkQuality.values,
        json['networkQuality'],
        NetworkQuality.unknown,
      ),
      cloudAiOnline: json['cloudAiOnline'] as bool? ?? false,
      cameraBlocked: json['cameraBlocked'] as bool? ?? false,
      batteryPercent: (json['batteryPercent'] as num?)?.toInt(),
    );
  }
}

class CameraDevice {
  const CameraDevice({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.location,
    required this.operatorUserId,
    required this.deviceId,
    required this.createdAt,
    required this.monitoring,
    required this.heartbeat,
    this.schedule = const MonitoringSchedule(),
    this.thumbnailPath,
    this.mutedAlerts = false,
  });

  final String id;
  final String organizationId;
  final String name;
  final String location;
  final String operatorUserId;
  final String deviceId;
  final DateTime createdAt;
  final bool monitoring;
  final DeviceHeartbeat heartbeat;
  final MonitoringSchedule schedule;
  final String? thumbnailPath;
  final bool mutedAlerts;

  CameraDevice copyWith({
    String? name,
    String? location,
    bool? monitoring,
    DeviceHeartbeat? heartbeat,
    MonitoringSchedule? schedule,
    String? thumbnailPath,
    bool? mutedAlerts,
  }) {
    return CameraDevice(
      id: id,
      organizationId: organizationId,
      name: name ?? this.name,
      location: location ?? this.location,
      operatorUserId: operatorUserId,
      deviceId: deviceId,
      createdAt: createdAt,
      monitoring: monitoring ?? this.monitoring,
      heartbeat: heartbeat ?? this.heartbeat,
      schedule: schedule ?? this.schedule,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      mutedAlerts: mutedAlerts ?? this.mutedAlerts,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationId': organizationId,
        'name': name,
        'location': location,
        'operatorUserId': operatorUserId,
        'deviceId': deviceId,
        'createdAt': writeTime(createdAt),
        'monitoring': monitoring,
        'heartbeat': heartbeat.toJson(),
        'schedule': schedule.toJson(),
        'thumbnailPath': thumbnailPath,
        'mutedAlerts': mutedAlerts,
      };

  factory CameraDevice.fromJson(Map<String, dynamic> json) {
    return CameraDevice(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      name: json['name'] as String? ?? 'Camera',
      location: json['location'] as String? ?? '',
      operatorUserId: json['operatorUserId'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      createdAt: parseTime(json['createdAt']),
      monitoring: json['monitoring'] as bool? ?? false,
      heartbeat: DeviceHeartbeat.fromJson(json['heartbeat'] as Map<String, dynamic>?),
      schedule: MonitoringSchedule.fromJson(json['schedule'] as Map<String, dynamic>?),
      thumbnailPath: json['thumbnailPath'] as String?,
      mutedAlerts: json['mutedAlerts'] as bool? ?? false,
    );
  }
}

bool isCameraOnline(
  DeviceHeartbeat heartbeat,
  DateTime now, {
  Duration window = const Duration(seconds: 45),
}) {
  if (heartbeat.operationalState == OperationalState.offline) return false;
  return now.difference(heartbeat.monitoredAt) <= window &&
      heartbeat.operationalState == OperationalState.monitoring;
}

class HeartbeatWriter {
  const HeartbeatWriter({this.quietPeriod = const Duration(seconds: 25)});

  final Duration quietPeriod;

  bool shouldWrite({
    required DeviceHeartbeat? previous,
    required DeviceHeartbeat next,
    required DateTime now,
  }) {
    if (previous == null) return true;
    if (now.difference(previous.monitoredAt) >= quietPeriod) return true;
    return previous.riskLevel != next.riskLevel ||
        previous.peopleCount != next.peopleCount ||
        previous.operationalState != next.operationalState ||
        previous.cameraBlocked != next.cameraBlocked ||
        previous.aiStatus != next.aiStatus ||
        previous.activity != next.activity;
  }
}

List<String> cameraHealthFlags(CameraDevice camera, DateTime now) {
  final flags = <String>[];
  if (!isCameraOnline(camera.heartbeat, now)) flags.add('OFFLINE');
  final battery = camera.heartbeat.batteryPercent;
  if (battery != null && battery < 15 && !camera.heartbeat.charging) {
    flags.add('LOW BATTERY');
  }
  if (camera.heartbeat.cameraBlocked) flags.add('CAMERA BLOCKED');
  if (camera.heartbeat.aiStatus == AiStatus.disabled ||
      camera.heartbeat.aiStatus == AiStatus.failed) {
    flags.add('AI DISABLED');
  }
  return flags;
}
