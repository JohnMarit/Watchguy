import 'dart:math';

import '../../../core/security/secret_hash.dart';
import '../../../core/time/clock.dart';
import '../../camera/domain/camera_device.dart';
import 'pairing_token.dart';

class PairingRejection implements Exception {
  const PairingRejection(this.message);

  final String message;

  @override
  String toString() => message;
}

class PairingService {
  PairingService({
    required this.clock,
    this.ttl = const Duration(minutes: 10),
    Random? random,
  }) : _random = random ?? Random.secure();

  final Clock clock;
  final Duration ttl;
  final Random _random;

  PairingInvitation issue({
    required String tokenId,
    required String organizationId,
    required String createdBy,
  }) {
    final secret = _randomSecret();
    final expiresAt = clock.now().add(ttl);
    final token = StoredPairingToken(
      id: tokenId,
      organizationId: organizationId,
      secretHash: hashSecret(secret),
      createdBy: createdBy,
      expiresAt: expiresAt,
    );
    return PairingInvitation(
      payload: PairingPayload(
        organizationId: organizationId,
        tokenId: tokenId,
        secret: secret,
        expiresAt: expiresAt,
      ),
      token: token,
    );
  }

  void assertRedeemable({
    required StoredPairingToken? token,
    required PairingPayload payload,
  }) {
    if (token == null || token.organizationId != payload.organizationId) {
      throw const PairingRejection('This pairing code is not valid.');
    }
    if (token.consumedAt != null) {
      throw const PairingRejection('This pairing code has already been used.');
    }
    if (!clock.now().isBefore(token.expiresAt)) {
      throw const PairingRejection('This pairing code has expired.');
    }
    if (!secretsMatch(payload.secret, token.secretHash)) {
      throw const PairingRejection('This pairing code is not valid.');
    }
  }

  /// Checks a code that this device never stored, which is the normal case when
  /// the owner's phone issued it and there is no shared backend. Possession of
  /// the secret from the owner's screen is the proof; the expiry still applies.
  void assertPayloadUsable(PairingPayload payload) {
    if (payload.organizationId.isEmpty || payload.secret.isEmpty) {
      throw const PairingRejection('This pairing code is not valid.');
    }
    if (!clock.now().isBefore(payload.expiresAt)) {
      throw const PairingRejection('This pairing code has expired. Create a new one.');
    }
  }

  CameraDevice redeem({
    required StoredPairingToken? token,
    required PairingPayload payload,
    required String cameraId,
    required String operatorUserId,
    required String deviceId,
    required String name,
    required String location,
  }) {
    if (token == null) {
      assertPayloadUsable(payload);
    } else {
      assertRedeemable(token: token, payload: payload);
    }
    return CameraDevice(
      id: cameraId,
      organizationId: payload.organizationId,
      name: name.trim().isEmpty ? 'Camera' : name.trim(),
      location: location.trim(),
      operatorUserId: operatorUserId,
      deviceId: deviceId,
      createdAt: clock.now(),
      monitoring: false,
      heartbeat: DeviceHeartbeat.idle(clock.now()),
    );
  }

  String _randomSecret() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
