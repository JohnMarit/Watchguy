import 'dart:async';

import '../../features/auth/domain/app_user.dart';
import '../../features/camera/domain/camera_device.dart';
import '../../features/incidents/domain/incident.dart';
import '../../features/live_stream/domain/live_session.dart';
import '../../features/organization/domain/organization.dart';
import '../../features/pairing/domain/pairing_token.dart';
import '../../features/zones/domain/security_rule.dart';
import '../../features/zones/domain/zone_geometry.dart';
import 'document_store.dart';

abstract class OrgDatabase {
  Stream<List<Organization>> watchOrganizations();
  Future<void> saveOrganization(Organization organization);
  Future<Organization?> organizationForUser(String userId);

  Stream<List<OrganizationMember>> watchMembers(String orgId);
  Future<void> saveMember(OrganizationMember member);

  Stream<List<CameraDevice>> watchCameras(String orgId);
  Future<CameraDevice?> getCamera(String orgId, String cameraId);
  Future<void> saveCamera(CameraDevice camera);
  Future<void> deleteCamera(String orgId, String cameraId);

  Stream<List<Incident>> watchIncidents(String orgId);
  Future<void> saveIncident(Incident incident);
  Future<void> deleteIncident(String orgId, String incidentId);

  Stream<List<SecurityZone>> watchZones(String orgId);
  Future<void> saveZone(SecurityZone zone);
  Future<void> deleteZone(String orgId, String zoneId);

  Future<SecurityRule> ruleFor(String orgId, {String? cameraId});
  Future<void> saveRule(SecurityRule rule);

  Future<void> savePairingToken(StoredPairingToken token);
  Future<StoredPairingToken?> getPairingToken(String orgId, String tokenId);

  Stream<List<LiveSession>> watchLiveSessions(String orgId);
  Future<void> saveLiveSession(LiveSession session);

  Future<void> saveUserProfile(AppUser user);
}

class LocalOrgDatabase implements OrgDatabase {
  LocalOrgDatabase(this.store);

  final DocumentStore store;

  @override
  Future<CameraDevice?> getCamera(String orgId, String cameraId) async {
    final json = await store.read('organizations/$orgId/cameras/$cameraId');
    return json == null ? null : CameraDevice.fromJson(json);
  }

  @override
  Future<StoredPairingToken?> getPairingToken(String orgId, String tokenId) async {
    final json = await store.read('organizations/$orgId/pairingTokens/$tokenId');
    return json == null ? null : StoredPairingToken.fromJson(json);
  }

  @override
  Future<Organization?> organizationForUser(String userId) async {
    final user = await store.read('users/$userId');
    final orgId = user?['organizationId'] as String?;
    if (orgId == null) return null;
    final json = await store.read('organizations/$orgId');
    return json == null ? null : Organization.fromJson(json);
  }

  @override
  Future<SecurityRule> ruleFor(String orgId, {String? cameraId}) async {
    if (cameraId != null) {
      final specific = await store.read('organizations/$orgId/rules/$cameraId');
      if (specific != null) return SecurityRule.fromJson(specific);
    }
    final fallback = await store.read('organizations/$orgId/rules/default');
    if (fallback != null) return SecurityRule.fromJson(fallback);
    return SecurityRule.defaults(orgId);
  }

  @override
  Future<void> deleteCamera(String orgId, String cameraId) {
    return store.delete('organizations/$orgId/cameras/$cameraId');
  }

  @override
  Future<void> deleteIncident(String orgId, String incidentId) {
    return store.delete('organizations/$orgId/incidents/$incidentId');
  }

  @override
  Future<void> deleteZone(String orgId, String zoneId) {
    return store.delete('organizations/$orgId/zones/$zoneId');
  }

  @override
  Future<void> saveCamera(CameraDevice camera) {
    return store.write(
      'organizations/${camera.organizationId}/cameras/${camera.id}',
      camera.toJson(),
    );
  }

  @override
  Future<void> saveIncident(Incident incident) {
    return store.write(
      'organizations/${incident.organizationId}/incidents/${incident.id}',
      incident.toJson(),
    );
  }

  @override
  Future<void> saveLiveSession(LiveSession session) {
    return store.write(
      'organizations/${session.organizationId}/liveSessions/${session.id}',
      session.toJson(),
    );
  }

  @override
  Future<void> saveMember(OrganizationMember member) async {
    await store.write(
      'organizations/${member.organizationId}/members/${member.userId}',
      member.toJson(),
    );
    final existing = await store.read('users/${member.userId}') ?? {'id': member.userId};
    existing['organizationId'] = member.organizationId;
    await store.write('users/${member.userId}', existing);
  }

  @override
  Future<void> saveOrganization(Organization organization) {
    return store.write('organizations/${organization.id}', organization.toJson());
  }

  @override
  Future<void> savePairingToken(StoredPairingToken token) {
    return store.write(
      'organizations/${token.organizationId}/pairingTokens/${token.id}',
      token.toJson(),
    );
  }

  @override
  Future<void> saveRule(SecurityRule rule) {
    final id = rule.cameraId ?? rule.id;
    return store.write('organizations/${rule.organizationId}/rules/$id', rule.toJson());
  }

  @override
  Future<void> saveUserProfile(AppUser user) {
    return store.write('users/${user.id}', user.toJson());
  }

  @override
  Future<void> saveZone(SecurityZone zone) {
    return store.write('organizations/${zone.organizationId}/zones/${zone.id}', zone.toJson());
  }

  @override
  Stream<List<CameraDevice>> watchCameras(String orgId) {
    return store.watch('organizations/$orgId/cameras').map(
          (docs) => docs.map(CameraDevice.fromJson).toList(),
        );
  }

  @override
  Stream<List<Incident>> watchIncidents(String orgId) {
    return store.watch('organizations/$orgId/incidents').map((docs) {
      final incidents = docs.map(Incident.fromJson).toList();
      incidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return incidents;
    });
  }

  @override
  Stream<List<LiveSession>> watchLiveSessions(String orgId) {
    return store.watch('organizations/$orgId/liveSessions').map(
          (docs) => docs.map(LiveSession.fromJson).toList(),
        );
  }

  @override
  Stream<List<OrganizationMember>> watchMembers(String orgId) {
    return store.watch('organizations/$orgId/members').map(
          (docs) => docs.map(OrganizationMember.fromJson).toList(),
        );
  }

  @override
  Stream<List<Organization>> watchOrganizations() {
    return Stream.fromFuture(_organizations()).asyncExpand((initial) async* {
      yield initial;
      yield* store.watch('organizations').map(
            (docs) => docs.map(Organization.fromJson).toList(),
          );
    });
  }

  @override
  Stream<List<SecurityZone>> watchZones(String orgId) {
    return store.watch('organizations/$orgId/zones').map(
          (docs) => docs.map(SecurityZone.fromJson).toList(),
        );
  }

  Future<List<Organization>> _organizations() async {
    final docs = await store.list('organizations');
    return docs.map(Organization.fromJson).toList();
  }
}
