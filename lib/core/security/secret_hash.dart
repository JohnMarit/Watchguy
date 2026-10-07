import 'dart:convert';

import 'package:crypto/crypto.dart';

String hashSecret(String secret) {
  return sha256.convert(utf8.encode(secret)).toString();
}

bool secretsMatch(String secret, String expectedHash) {
  return hashSecret(secret) == expectedHash;
}
