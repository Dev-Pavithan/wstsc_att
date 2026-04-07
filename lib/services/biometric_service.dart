import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();
  static const String _lockEnabledKey = 'biometric_lock_enabled';

  static Future<bool> isAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics && isDeviceSupported;
    } catch (e) {
      debugPrint('Biometric Availability error: $e');
      return false;
    }
  }

  static Future<bool> authenticate() async {
    if (!await isAvailable()) {
      debugPrint('Biometrics not available on this hardware.');
      return false;
    }

    try {
      // Trigger system biometric prompt (Absolute base parameters for cross-platform compatibility)
      return await _auth.authenticate(
        localizedReason: 'Authenticate using Fingerprint to access WSTSC',
      );
    } catch (e) {
      debugPrint('Authentication Error: $e');
      return false;
    }
  }

  static Future<bool> isLockEnabled() async {
    final value = await _storage.read(key: _lockEnabledKey);
    return value == 'true';
  }

  static Future<void> setLockEnabled(bool enabled) async {
    await _storage.write(key: _lockEnabledKey, value: enabled.toString());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockEnabledKey, enabled);
  }
}
