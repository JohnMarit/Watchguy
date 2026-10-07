import '../../camera/domain/camera_device.dart';
import '../../../core/models/enums.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.cameras,
    required this.online,
    required this.offline,
    required this.alerts,
  });

  final int cameras;
  final int online;
  final int offline;
  final int alerts;

  factory DashboardSummary.fromCameras(List<CameraDevice> cameras, DateTime now) {
    var online = 0;
    var alerts = 0;
    for (final camera in cameras) {
      final live = isCameraOnline(camera.heartbeat, now);
      if (live) online += 1;
      final level = camera.heartbeat.riskLevel;
      if (live && (level == RiskLevel.high || level == RiskLevel.critical)) {
        alerts += 1;
      }
    }
    return DashboardSummary(
      cameras: cameras.length,
      online: online,
      offline: cameras.length - online,
      alerts: alerts,
    );
  }
}

int compareCamerasByPriority(CameraDevice a, CameraDevice b, DateTime now) {
  final aAlert = isCameraOnline(a.heartbeat, now) ? a.heartbeat.riskLevel.rank : -1;
  final bAlert = isCameraOnline(b.heartbeat, now) ? b.heartbeat.riskLevel.rank : -1;
  final byRisk = bAlert.compareTo(aAlert);
  if (byRisk != 0) return byRisk;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
