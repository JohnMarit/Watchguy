import 'package:flutter_test/flutter_test.dart';
import 'package:watchguy/core/storage/document_store.dart';
import 'package:watchguy/core/storage/org_database.dart';
import 'package:watchguy/features/auth/data/demo_accounts.dart';
import 'package:watchguy/features/auth/data/local_auth_repository.dart';
import 'package:watchguy/features/camera/domain/camera_device.dart';

void main() {
  test('demo accounts sign in to a seeded organization', () async {
    final store = MemoryDocumentStore();
    final database = LocalOrgDatabase(store);
    final now = DateTime.utc(2026, 10, 5, 12);
    await seedDemoAccounts(store: store, database: database, now: now);
    await seedDemoAccounts(store: store, database: database, now: now);

    final auth = LocalAuthRepository(store);
    final owner = await auth.signInWithEmail(email: 'owner@watchguy.demo', password: demoPassword);
    expect(owner.emailVerified, isTrue);
    expect(owner.displayName, 'Alex Rivera');

    final organization = await database.organizationForUser(owner.id);
    expect(organization?.name, 'Harbor Yard');

    final cameras = await database.watchCameras(demoOrganizationId).first;
    expect(cameras, hasLength(4));
    final gate = cameras.firstWhere((camera) => camera.id == demoMainGateId);
    expect(isCameraOnline(gate.heartbeat, now), isTrue);
    final warehouse = cameras.firstWhere((camera) => camera.id == 'cam_warehouse');
    expect(isCameraOnline(warehouse.heartbeat, now), isFalse);

    final incidents = await database.watchIncidents(demoOrganizationId).first;
    expect(incidents, hasLength(3));
    expect(incidents.first.id, 'inc_gate_restricted');

    final operator = await auth.signInWithEmail(email: 'camera@watchguy.demo', password: demoPassword);
    expect(demoAccountFor(operator)?.activeCameraId, demoMainGateId);
  });
}
