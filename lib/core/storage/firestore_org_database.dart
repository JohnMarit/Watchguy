import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/camera/domain/camera_device.dart';
import '../../features/incidents/domain/incident.dart';
import '../../features/live_stream/domain/live_session.dart';
import '../../features/organization/domain/organization.dart';
import '../../features/pairing/domain/pairing_token.dart';
import '../../features/zones/domain/security_rule.dart';
import '../../features/zones/domain/zone_geometry.dart';
import 'org_database.dart';

class FirestoreOrgDatabase implements OrgDatabase {
  FirestoreOrgDatabase(this.firestore);

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> _orgs() => firestore.collection('organizations');

  @override
  Future<void> deleteCamera(String orgId, String cameraId) {
    return _orgs().doc(orgId).collection('cameras').doc(cameraId).delete();
  }

  @override
  Future<void> deleteIncident(String orgId, String incidentId) {
    return _orgs().doc(orgId).collection('incidents').doc(incidentId).delete();
  }

  @override
  Future<void> deleteZone(String orgId, String zoneId) {
    return _orgs().doc(orgId).collection('zones').doc(zoneId).delete();
  }

  @override
  Future<CameraDevice?> getCamera(String orgId, String cameraId) async {
    final snap = await _orgs().doc(orgId).collection('cameras').doc(cameraId).get();
    final data = snap.data();
    return data == null ? null : CameraDevice.fromJson(data);
  }

  @override
  Future<StoredPairingToken?> getPairingToken(String orgId, String tokenId) async {
    final snap = await _orgs().doc(orgId).collection('pairingTokens').doc(tokenId).get();
    final data = snap.data();
    return data == null ? null : StoredPairingToken.fromJson(data);
  }

  @override
  Future<Organization?> organizationForUser(String userId) async {
    final user = await firestore.collection('users').doc(userId).get();
    final orgId = user.data()?['organizationId'] as String?;
    if (orgId == null) return null;
    final org = await _orgs().doc(orgId).get();
    final data = org.data();
    return data == null ? null : Organization.fromJson(data);
  }

  @override
  Future<SecurityRule> ruleFor(String orgId, {String? cameraId}) async {
    if (cameraId != null) {
      final specific = await _orgs().doc(orgId).collection('rules').doc(cameraId).get();
      final data = specific.data();
      if (data != null) return SecurityRule.fromJson(data);
    }
    final fallback = await _orgs().doc(orgId).collection('rules').doc('default').get();
    final data = fallback.data();
    if (data != null) return SecurityRule.fromJson(data);
    return SecurityRule.defaults(orgId);
  }

  @override
  Future<void> saveCamera(CameraDevice camera) {
    return _orgs()
        .doc(camera.organizationId)
        .collection('cameras')
        .doc(camera.id)
        .set(camera.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> saveIncident(Incident incident) {
    return _orgs()
        .doc(incident.organizationId)
        .collection('incidents')
        .doc(incident.id)
        .set(incident.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> saveLiveSession(LiveSession session) {
    return _orgs()
        .doc(session.organizationId)
        .collection('liveSessions')
        .doc(session.id)
        .set(session.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> saveMember(OrganizationMember member) async {
    await _orgs()
        .doc(member.organizationId)
        .collection('members')
        .doc(member.userId)
        .set(member.toJson(), SetOptions(merge: true));
    await firestore.collection('users').doc(member.userId).set(
      {'organizationId': member.organizationId},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> saveOrganization(Organization organization) {
    return _orgs().doc(organization.id).set(organization.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> savePairingToken(StoredPairingToken token) {
    return _orgs()
        .doc(token.organizationId)
        .collection('pairingTokens')
        .doc(token.id)
        .set(token.toJson());
  }

  @override
  Future<void> saveRule(SecurityRule rule) {
    final id = rule.cameraId ?? rule.id;
    return _orgs().doc(rule.organizationId).collection('rules').doc(id).set(rule.toJson());
  }

  @override
  Future<void> saveUserProfile(AppUser user) {
    return firestore.collection('users').doc(user.id).set(user.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> saveZone(SecurityZone zone) {
    return _orgs()
        .doc(zone.organizationId)
        .collection('zones')
        .doc(zone.id)
        .set(zone.toJson(), SetOptions(merge: true));
  }

  @override
  Stream<List<CameraDevice>> watchCameras(String orgId) {
    return _orgs().doc(orgId).collection('cameras').snapshots().map(
          (snap) => snap.docs.map((doc) => CameraDevice.fromJson(doc.data())).toList(),
        );
  }

  @override
  Stream<List<Incident>> watchIncidents(String orgId) {
    return _orgs()
        .doc(orgId)
        .collection('incidents')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Incident.fromJson(doc.data())).toList());
  }

  @override
  Stream<List<LiveSession>> watchLiveSessions(String orgId) {
    return _orgs().doc(orgId).collection('liveSessions').snapshots().map(
          (snap) => snap.docs.map((doc) => LiveSession.fromJson(doc.data())).toList(),
        );
  }

  @override
  Stream<List<OrganizationMember>> watchMembers(String orgId) {
    return _orgs().doc(orgId).collection('members').snapshots().map(
          (snap) => snap.docs.map((doc) => OrganizationMember.fromJson(doc.data())).toList(),
        );
  }

  @override
  Stream<List<Organization>> watchOrganizations() {
    return _orgs().snapshots().map(
          (snap) => snap.docs.map((doc) => Organization.fromJson(doc.data())).toList(),
        );
  }

  @override
  Stream<List<SecurityZone>> watchZones(String orgId) {
    return _orgs().doc(orgId).collection('zones').snapshots().map(
          (snap) => snap.docs.map((doc) => SecurityZone.fromJson(doc.data())).toList(),
        );
  }
}
