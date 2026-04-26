import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuth {
  static final LocalAuthentication _localAuth = LocalAuthentication();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTokenKey = 'biometric_token';

  /// Check if device supports biometric authentication
  static Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      debugPrint('Biometric check error: ${e.message}');
      return false;
    }
  }

  /// Check if biometrics are available on this device
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      debugPrint('Biometric check error: ${e.message}');
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('Biometric types error: ${e.message}');
      return [];
    }
  }

  /// Authenticate with biometrics
  static Future<bool> authenticate() async {
    try {
      final bool isAvailable = await canCheckBiometrics();
      if (!isAvailable) return false;

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint or face to access Ritme',
        authMessages: const [
          const AndroidAuthMessages(
            signInTitle: 'Biometric Authentication',
            cancelButton: 'Cancel',
            biometricHint: 'Verify your identity',
            biometricNotRecognized: 'Not recognized, try again',
            biometricRequiredTitle: 'Biometric authentication required',
            biometricSuccess: 'Authentication successful',
            deviceCredentialsRequiredTitle: 'Device credentials required',
            deviceCredentialsSetupDescription: 'Please set up device credentials',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription: 'Please set up biometric authentication in your device settings',
          ),
          const IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Go to Settings',
            goToSettingsDescription: 'Please set up biometric authentication in your device settings',
            lockOut: 'Please reenable biometric authentication',
          ),
        ],
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Authentication error: ${e.message}');
      return false;
    }
  }

  /// Check if biometric authentication is enabled
  static Future<bool> isBiometricEnabled() async {
    final String? value = await _secureStorage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  /// Enable biometric authentication
  static Future<void> enableBiometric() async {
    await _secureStorage.write(key: _biometricEnabledKey, value: 'true');
  }

  /// Disable biometric authentication
  static Future<void> disableBiometric() async {
    await _secureStorage.write(key: _biometricEnabledKey, value: 'false');
    await _secureStorage.delete(key: _biometricTokenKey);
  }

  /// Store authentication token securely
  static Future<void> storeToken(String token) async {
    await _secureStorage.write(key: _biometricTokenKey, value: token);
  }

  /// Retrieve authentication token
  static Future<String?> getToken() async {
    return await _secureStorage.read(key: _biometricTokenKey);
  }

  /// Clear all biometric data
  static Future<void> clearBiometricData() async {
    await _secureStorage.delete(key: _biometricEnabledKey);
    await _secureStorage.delete(key: _biometricTokenKey);
  }
}
