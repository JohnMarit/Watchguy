import '../../../core/models/enums.dart';
import '../../../core/time/json_time.dart';

class LiveSession {
  const LiveSession({
    required this.id,
    required this.organizationId,
    required this.cameraId,
    required this.requestedBy,
    required this.state,
    required this.createdAt,
  });

  final String id;
  final String organizationId;
  final String cameraId;
  final String requestedBy;
  final LiveSessionState state;
  final DateTime createdAt;

  LiveSession copyWith({LiveSessionState? state}) {
    return LiveSession(
      id: id,
      organizationId: organizationId,
      cameraId: cameraId,
      requestedBy: requestedBy,
      state: state ?? this.state,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationId': organizationId,
        'cameraId': cameraId,
        'requestedBy': requestedBy,
        'state': state.name,
        'createdAt': writeTime(createdAt),
      };

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      cameraId: json['cameraId'] as String,
      requestedBy: json['requestedBy'] as String? ?? '',
      state: enumByName(LiveSessionState.values, json['state'], LiveSessionState.requested),
      createdAt: parseTime(json['createdAt']),
    );
  }
}

class LiveKitCredentials {
  const LiveKitCredentials({
    required this.url,
    required this.room,
    required this.token,
    required this.role,
  });

  final String url;
  final String room;
  final String token;
  final LiveRole role;
}
