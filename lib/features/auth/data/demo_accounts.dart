import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/models/enums.dart';
import '../../../core/storage/document_store.dart';
import '../../../core/storage/org_database.dart';
import '../../camera/domain/camera_device.dart';
import '../../incidents/domain/incident.dart';
import '../../organization/domain/organization.dart';
import '../../zones/domain/monitoring_schedule.dart';
import '../../zones/domain/zone_geometry.dart';
import '../domain/app_user.dart';

const demoPassword = 'demo1234';
const demoOrganizationId = 'org_harbor_yard';
const demoMainGateId = 'cam_main_gate';

class DemoAccount {
  const DemoAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.mode,
    required this.title,
    required this.detail,
    this.activeCameraId,
  });

  final String id;
  final String email;
  final String displayName;
  final MemberRole role;
  final AppMode mode;
  final String title;
  final String detail;
  final String? activeCameraId;
}

const demoAccounts = <DemoAccount>[
  DemoAccount(
    id: 'demo_owner',
    email: 'owner@watchguy.demo',
    displayName: 'Alex Rivera',
    role: MemberRole.owner,
    mode: AppMode.dashboard,
    title: 'Owner',
    detail: 'Dashboard · Harbor Yard',
  ),
  DemoAccount(
    id: 'demo_camera',
    email: 'camera@watchguy.demo',
    displayName: 'Sam Okonkwo',
    role: MemberRole.securityOperator,
    mode: AppMode.camera,
    title: 'Camera phone',
    detail: 'Camera · Main Gate',
    activeCameraId: demoMainGateId,
  ),
];

DemoAccount? demoAccountFor(AppUser user) {
  for (final account in demoAccounts) {
    if (account.id == user.id) return account;
  }
  return null;
}

/// Writes the local demo users, organization, cameras, and incidents.
/// Safe to call on every launch: known records are refreshed, other data is left alone.
Future<void> seedDemoAccounts({
  required DocumentStore store,
  required OrgDatabase database,
  required DateTime now,
}) async {
  final createdAt = DateTime.utc(2026, 3, 2, 9);
  final organization = Organization(
    id: demoOrganizationId,
    name: 'Harbor Yard',
    ownerId: 'demo_owner',
    createdAt: createdAt,
  );
  await database.saveOrganization(organization);

  for (final account in demoAccounts) {
    final user = AppUser(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      emailVerified: true,
    );
    await store.write('authUsers/${account.id}', user.toJson());
    await store.write('authSecrets/${account.id}', {
      'salt': 'watchguy-demo',
      'hash': sha256.convert(utf8.encode('watchguy-demo:$demoPassword')).toString(),
    });
    await database.saveMember(OrganizationMember(
      userId: account.id,
      organizationId: organization.id,
      role: account.role,
      createdAt: createdAt,
      email: account.email,
    ));
  }

  final cameras = _cameras(now);
  for (final camera in cameras) {
    await database.saveCamera(camera);
  }
  await database.saveZone(SecurityZone(
    id: 'zone_gate_restricted',
    organizationId: organization.id,
    cameraId: demoMainGateId,
    name: 'After-hours gate',
    type: ZoneType.restricted,
    points: const [
      NormPoint(0.08, 0.42),
      NormPoint(0.62, 0.38),
      NormPoint(0.7, 0.92),
      NormPoint(0.05, 0.94),
    ],
    createdAt: createdAt,
  ));

  for (final incident in _incidents(organization.id, now)) {
    await database.saveIncident(incident);
  }
}

List<CameraDevice> _cameras(DateTime now) {
  return [
    CameraDevice(
      id: demoMainGateId,
      organizationId: demoOrganizationId,
      name: 'Main Gate',
      location: 'North entrance',
      operatorUserId: 'demo_camera',
      deviceId: 'demo-device-gate',
      createdAt: DateTime.utc(2026, 3, 2, 10),
      monitoring: true,
      schedule: const MonitoringSchedule(alwaysArmed: true),
      heartbeat: DeviceHeartbeat(
        operationalState: OperationalState.monitoring,
        aiStatus: AiStatus.active,
        monitoredAt: now,
        charging: false,
        peopleCount: 1,
        riskLevel: RiskLevel.high,
        riskScore: 78,
        activity: 'Person inside the restricted zone',
        networkQuality: NetworkQuality.good,
        cloudAiOnline: false,
        cameraBlocked: false,
        batteryPercent: 76,
      ),
    ),
    CameraDevice(
      id: 'cam_reception',
      organizationId: demoOrganizationId,
      name: 'Reception',
      location: 'Front desk',
      operatorUserId: 'demo_camera',
      deviceId: 'demo-device-reception',
      createdAt: DateTime.utc(2026, 3, 4, 11),
      monitoring: true,
      schedule: const MonitoringSchedule(alwaysArmed: true),
      heartbeat: DeviceHeartbeat(
        operationalState: OperationalState.monitoring,
        aiStatus: AiStatus.active,
        monitoredAt: now,
        charging: true,
        peopleCount: 0,
        riskLevel: RiskLevel.normal,
        riskScore: 8,
        activity: 'Area clear',
        networkQuality: NetworkQuality.good,
        cloudAiOnline: false,
        cameraBlocked: false,
        batteryPercent: 94,
      ),
    ),
    CameraDevice(
      id: 'cam_parking',
      organizationId: demoOrganizationId,
      name: 'Parking',
      location: 'West lot',
      operatorUserId: 'demo_camera',
      deviceId: 'demo-device-parking',
      createdAt: DateTime.utc(2026, 3, 6, 14),
      monitoring: true,
      schedule: MonitoringSchedule.nights(),
      heartbeat: DeviceHeartbeat(
        operationalState: OperationalState.monitoring,
        aiStatus: AiStatus.cloudOffline,
        monitoredAt: now,
        charging: false,
        peopleCount: 2,
        riskLevel: RiskLevel.medium,
        riskScore: 52,
        activity: 'Two people near the entrance',
        networkQuality: NetworkQuality.fair,
        cloudAiOnline: false,
        cameraBlocked: false,
        batteryPercent: 41,
      ),
    ),
    CameraDevice(
      id: 'cam_warehouse',
      organizationId: demoOrganizationId,
      name: 'Warehouse',
      location: 'Loading dock',
      operatorUserId: 'demo_camera',
      deviceId: 'demo-device-warehouse',
      createdAt: DateTime.utc(2026, 3, 8, 8),
      monitoring: false,
      heartbeat: DeviceHeartbeat(
        operationalState: OperationalState.offline,
        aiStatus: AiStatus.idle,
        monitoredAt: now.subtract(const Duration(hours: 6)),
        charging: false,
        peopleCount: 0,
        riskLevel: RiskLevel.normal,
        riskScore: 0,
        activity: '',
        networkQuality: NetworkQuality.unknown,
        cloudAiOnline: false,
        cameraBlocked: false,
        batteryPercent: 9,
      ),
    ),
  ];
}

List<Incident> _incidents(String organizationId, DateTime now) {
  final gateStart = now.subtract(const Duration(minutes: 12));
  final parkingStart = now.subtract(const Duration(hours: 2));
  final warehouseStart = now.subtract(const Duration(hours: 26));
  return [
    Incident(
      id: 'inc_gate_restricted',
      organizationId: organizationId,
      cameraId: demoMainGateId,
      cameraName: 'Main Gate',
      createdAt: gateStart,
      eventStart: gateStart,
      eventEnd: gateStart.add(const Duration(seconds: 18)),
      riskLevel: RiskLevel.high,
      riskScore: 78,
      eventType: 'restricted_zone',
      description: 'A person remained inside the after-hours gate zone.',
      observations: const ['1 person', 'Restricted zone', 'After hours'],
      aiConfidence: 0.86,
      status: IncidentStatus.ready,
      reviewState: ReviewState.unreviewed,
      createdByEngine: 'demo',
      zoneName: 'After-hours gate',
    ),
    Incident(
      id: 'inc_parking_loiter',
      organizationId: organizationId,
      cameraId: 'cam_parking',
      cameraName: 'Parking',
      createdAt: parkingStart,
      eventStart: parkingStart,
      eventEnd: parkingStart.add(const Duration(seconds: 40)),
      riskLevel: RiskLevel.medium,
      riskScore: 52,
      eventType: 'loitering',
      description: 'Two people stayed near the parking entrance.',
      observations: const ['2 people', 'Entrance zone'],
      aiConfidence: 0.71,
      status: IncidentStatus.reviewed,
      reviewState: ReviewState.unsure,
      createdByEngine: 'demo',
      zoneName: 'Entrance',
    ),
    Incident(
      id: 'inc_warehouse_motion',
      organizationId: organizationId,
      cameraId: 'cam_warehouse',
      cameraName: 'Warehouse',
      createdAt: warehouseStart,
      eventStart: warehouseStart,
      eventEnd: warehouseStart.add(const Duration(seconds: 9)),
      riskLevel: RiskLevel.low,
      riskScore: 28,
      eventType: 'motion',
      description: 'Brief motion at the loading dock, then the area cleared.',
      observations: const ['Motion', 'No person confirmed'],
      aiConfidence: 0.44,
      status: IncidentStatus.reviewed,
      reviewState: ReviewState.falseAlarm,
      createdByEngine: 'demo',
    ),
  ];
}
