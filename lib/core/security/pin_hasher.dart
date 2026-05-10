import 'dart:convert';

import 'package:crypto/crypto.dart';

class PinHasher {
  const PinHasher();

  static const _namespace = 'macbec_solar_app_local_auth_v1';

  String hash(String pin) {
    final normalizedPin = pin.trim();
    final bytes = utf8.encode('$_namespace:$normalizedPin');
    return sha256.convert(bytes).toString();
  }

  bool verify({
    required String pin,
    required String storedHash,
  }) {
    return hash(pin) == storedHash;
  }
}
