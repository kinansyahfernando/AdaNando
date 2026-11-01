import 'package:flutter/services.dart';

/// Memblokir screenshot & rekam layar (Android, lewat FLAG_SECURE).
/// Di web / platform lain pemanggilan ini diabaikan tanpa error.
class SecureScreen {
  SecureScreen._();

  static const MethodChannel _channel = MethodChannel('adanando/secure');

  static Future<void> enable() => _call('enable');

  static Future<void> disable() => _call('disable');

  static Future<void> _call(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // Tidak didukung di platform ini (mis. web): abaikan.
    }
  }
}
