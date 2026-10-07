enum MemberRole { owner, admin, securityOperator, viewer }

enum AppMode { camera, dashboard }

enum RiskLevel { normal, low, medium, high, critical }

enum IncidentStatus {
  detected,
  recording,
  processing,
  ready,
  notified,
  reviewed,
  dismissed,
}

enum ReviewState { unreviewed, confirmed, falseAlarm, unsure }

enum ZoneType { restricted, entrance, exit, watchArea, ignoredArea }

enum OperationalState { idle, monitoring, unavailable, permissionDenied, overheating, offline }

enum AiStatus { idle, active, cloudOffline, failed, disabled }

enum DataSaverMode { lowData, balanced, highQuality }

enum NetworkQuality { unknown, poor, fair, good }

enum LiveSessionState { requested, publishing, active, closed }

enum LiveRole { publisher, subscriber }

extension RiskLevelRank on RiskLevel {
  int get rank => switch (this) {
        RiskLevel.normal => 0,
        RiskLevel.low => 1,
        RiskLevel.medium => 2,
        RiskLevel.high => 3,
        RiskLevel.critical => 4,
      };

  String get label => switch (this) {
        RiskLevel.normal => 'NORMAL',
        RiskLevel.low => 'LOW',
        RiskLevel.medium => 'MEDIUM',
        RiskLevel.high => 'HIGH',
        RiskLevel.critical => 'CRITICAL',
      };
}

extension MemberRoleLabel on MemberRole {
  String get label => switch (this) {
        MemberRole.owner => 'Owner',
        MemberRole.admin => 'Admin',
        MemberRole.securityOperator => 'Security operator',
        MemberRole.viewer => 'Viewer',
      };
}

T enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
