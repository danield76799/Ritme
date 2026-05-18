import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityHelper {
  /// Hash een PIN met SHA-256 + salt
  static String hashPin(String pin, {String? salt}) {
    // Gebruik een device-specifieke salt als basis
    final effectiveSalt = salt ?? 'ritme_default_salt_2024';
    final bytes = utf8.encode(pin + effectiveSalt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifieer een PIN tegen een hash
  static bool verifyPin(String pin, String hashedPin, {String? salt}) {
    final hash = hashPin(pin, salt: salt);
    return hash == hashedPin;
  }

  /// Genereer een random salt
  static String generateSalt() {
    final random = List<int>.generate(16, (_) => DateTime.now().microsecond % 256);
    return base64Url.encode(random);
  }
}