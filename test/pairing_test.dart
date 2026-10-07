import 'package:flutter_test/flutter_test.dart';
import 'package:watchguy/core/storage/document_store.dart';
import 'package:watchguy/core/storage/org_database.dart';
import 'package:watchguy/core/time/clock.dart';
import 'package:watchguy/features/pairing/domain/pairing_service.dart';
import 'package:watchguy/features/pairing/domain/pairing_token.dart';

void main() {
  test('pairing tokens expire, are single-use, and never store the raw secret', () async {
    final clock = FakeClock(DateTime.utc(2026, 10, 5, 12));
    final service = PairingService(clock: clock);
    final invitation = service.issue(tokenId: 'tok', organizationId: 'org', createdBy: 'owner');
    expect(invitation.token.secretHash, isNot(contains(invitation.payload.secret)));
    expect(invitation.payload.encode(), isNot(contains('password')));

    final database = LocalOrgDatabase(MemoryDocumentStore());
    await database.savePairingToken(invitation.token);
    final camera = service.redeem(
      token: invitation.token,
      payload: PairingPayload.decode(invitation.payload.encode()),
      cameraId: 'cam',
      operatorUserId: 'user',
      deviceId: 'phone',
      name: 'Warehouse',
      location: 'Rear',
    );
    expect(camera.name, 'Warehouse');

    await database.savePairingToken(StoredPairingToken(
      id: invitation.token.id,
      organizationId: invitation.token.organizationId,
      secretHash: invitation.token.secretHash,
      createdBy: invitation.token.createdBy,
      expiresAt: invitation.token.expiresAt,
      consumedAt: clock.now(),
      consumedByDeviceId: 'phone',
    ));
    final consumed = await database.getPairingToken('org', 'tok');
    expect(
      () => service.assertRedeemable(token: consumed, payload: invitation.payload),
      throwsA(isA<PairingRejection>()),
    );

    clock.advance(const Duration(minutes: 11));
    expect(
      () => service.assertRedeemable(token: invitation.token, payload: invitation.payload),
      throwsA(isA<PairingRejection>()),
    );
    expect(() => PairingPayload.decode('not-json'), throwsFormatException);
  });

  test('a camera phone can claim a code this device never stored', () {
    final clock = FakeClock(DateTime.utc(2026, 10, 5, 12));
    final owner = PairingService(clock: clock);
    final invitation = owner.issue(tokenId: 'tok', organizationId: 'org', createdBy: 'owner');
    final scanned = PairingPayload.decode(invitation.payload.encode());

    // The camera phone has its own empty store, so the token lookup is null.
    final cameraPhone = PairingService(clock: clock);
    final camera = cameraPhone.redeem(
      token: null,
      payload: scanned,
      cameraId: 'cam',
      operatorUserId: 'operator',
      deviceId: 'phone-2',
      name: 'Main Gate',
      location: 'North entrance',
    );
    expect(camera.organizationId, 'org');
    expect(camera.name, 'Main Gate');
    expect(camera.location, 'North entrance');

    clock.advance(const Duration(minutes: 11));
    expect(
      () => cameraPhone.redeem(
        token: null,
        payload: scanned,
        cameraId: 'cam2',
        operatorUserId: 'operator',
        deviceId: 'phone-2',
        name: 'Main Gate',
        location: 'North entrance',
      ),
      throwsA(isA<PairingRejection>()),
    );
  });
}
