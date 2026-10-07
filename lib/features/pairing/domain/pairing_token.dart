import 'dart:convert';

import '../../../core/time/json_time.dart';

class StoredPairingToken {
  const StoredPairingToken({
    required this.id,
    required this.organizationId,
    required this.secretHash,
    required this.createdBy,
    required this.expiresAt,
    this.consumedAt,
    this.consumedByDeviceId,
  });

  final String id;
  final String organizationId;
  final String secretHash;
  final String createdBy;
  final DateTime expiresAt;
  final DateTime? consumedAt;
  final String? consumedByDeviceId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationId': organizationId,
        'secretHash': secretHash,
        'createdBy': createdBy,
        'expiresAt': writeTime(expiresAt),
        'consumedAt': consumedAt == null ? null : writeTime(consumedAt!),
        'consumedByDeviceId': consumedByDeviceId,
      };

  factory StoredPairingToken.fromJson(Map<String, dynamic> json) {
    return StoredPairingToken(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      secretHash: json['secretHash'] as String,
      createdBy: json['createdBy'] as String? ?? '',
      expiresAt: parseTime(json['expiresAt']),
      consumedAt: json['consumedAt'] == null ? null : parseTime(json['consumedAt']),
      consumedByDeviceId: json['consumedByDeviceId'] as String?,
    );
  }
}

class PairingPayload {
  const PairingPayload({
    required this.organizationId,
    required this.tokenId,
    required this.secret,
    required this.expiresAt,
    this.version = 1,
  });

  final int version;
  final String organizationId;
  final String tokenId;
  final String secret;
  final DateTime expiresAt;

  String encode() => jsonEncode({
        'v': version,
        'org': organizationId,
        'tid': tokenId,
        'secret': secret,
        'exp': expiresAt.toUtc().millisecondsSinceEpoch,
      });

  static PairingPayload decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map) {
      throw const FormatException('Pairing code is not valid.');
    }
    final version = (json['v'] as num?)?.toInt() ?? 0;
    if (version != 1) {
      throw const FormatException('This pairing code is from a newer app.');
    }
    return PairingPayload(
      version: version,
      organizationId: json['org'] as String,
      tokenId: json['tid'] as String,
      secret: json['secret'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch((json['exp'] as num).toInt(), isUtc: true),
    );
  }
}

class PairingInvitation {
  const PairingInvitation({
    required this.payload,
    required this.token,
  });

  final PairingPayload payload;
  final StoredPairingToken token;
}
