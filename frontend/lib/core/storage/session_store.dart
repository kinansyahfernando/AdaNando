import 'package:shared_preferences/shared_preferences.dart';

/// Menyimpan token login supaya siswa tidak perlu login ulang setiap
/// aplikasi / halaman web dibuka kembali (token tetap divalidasi server).
class SessionStore {
  SessionStore._();

  static const _key = 'ada_token';

  static Future<String?> readToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
    } catch (_) {
      // Penyimpanan tidak tersedia: abaikan, login tetap jalan di memori.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // abaikan
    }
  }
}
