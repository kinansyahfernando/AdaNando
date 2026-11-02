import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_navigator.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/session_store.dart';
import '../../data/datasources/auth_remote_datasource.dart';

/// Status login seluruh aplikasi. Layar yang tampil ditentukan oleh status ini
/// (lihat AuthGate di main.dart), jadi tidak ada navigasi manual setelah login.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    DioClient.onUnauthorized = _handleUnauthorized;
  }

  final _authDataSource = AuthRemoteDataSource();

  /// False selama aplikasi memeriksa sesi tersimpan saat pertama dibuka.
  bool ready = false;
  bool isLoading = false;
  String? errorMessage;

  /// Pesan di layar login (mis. "akunmu dipakai di perangkat lain").
  String? notice;

  bool allowRegister = false;

  int? userId;
  String? userRole; // 'admin' / 'guru' / 'siswa'
  String? userName;
  String? userNis;
  String? className;
  bool mustChangePassword = false;

  /// True sekali setelah login baru: admin / guru langsung dibawa ke panel web.
  /// (Tidak aktif saat sesi dipulihkan, supaya tombol Kembali tidak berputar.)
  bool autoOpenPanel = false;

  bool get isLoggedIn => userRole != null;

  /// Dipanggil sekali saat aplikasi dibuka: ambil pengaturan + pulihkan sesi.
  Future<void> init() async {
    try {
      final cfg = await _authDataSource.config();
      allowRegister = cfg['allowRegister'] == true;
    } catch (_) {
      allowRegister = false;
    }

    final saved = await SessionStore.readToken();
    if (saved != null && saved.isNotEmpty) {
      DioClient.setToken(saved);
      try {
        final res = await _authDataSource.me();
        _applyUser(res['user'] as Map<String, dynamic>);
      } catch (_) {
        DioClient.clearToken();
        await SessionStore.clear();
      }
    }
    ready = true;
    notifyListeners();
  }

  void _applyUser(Map<String, dynamic> user) {
    userId = user['id'] as int?;
    userRole = user['role']?.toString();
    userName = user['name']?.toString();
    userNis = user['nis']?.toString();
    className = user['className']?.toString();
    mustChangePassword = user['mustChangePassword'] == true;
  }

  Future<bool> login(String identifier, String password) async {
    isLoading = true;
    errorMessage = null;
    notice = null;
    notifyListeners();

    try {
      final response = await _authDataSource.login(identifier, password);

      // Bentuk respons backend: { message, token, user: { id, name, role, ... } }
      final token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;
      if (token == null || user == null) {
        throw Exception('Format respons server tidak valid');
      }

      DioClient.setToken(token);
      await SessionStore.saveToken(token);
      _applyUser(user);
      autoOpenPanel = userRole == 'admin' || userRole == 'guru';

      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = _readableError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authDataSource.register(name, email, password);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = _readableError(e);
      notifyListeners();
      return false;
    }
  }

  /// Ganti password (wajib untuk akun baru). Sesi diperbarui dengan token baru.
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final res = await _authDataSource.changePassword(oldPassword, newPassword);
      final token = res['token'] as String?;
      if (token != null) {
        DioClient.setToken(token);
        await SessionStore.saveToken(token);
      }
      mustChangePassword = false;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = _readableError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authDataSource.logout();
    await _clearLocal();
    notifyListeners();
  }

  Future<void> _clearLocal() async {
    DioClient.clearToken();
    await SessionStore.clear();
    userId = null;
    userRole = null;
    userName = null;
    userNis = null;
    className = null;
    mustChangePassword = false;
    autoOpenPanel = false;
    // Tutup semua halaman yang masih terbuka (ujian, hasil, dll)
    appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  /// Server menolak token: keluar paksa dan beri tahu alasannya.
  void _handleUnauthorized(String message) {
    if (!isLoggedIn) return;
    _clearLocal().then((_) {
      notice = message;
      notifyListeners();
    });
  }

  String _readableError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          // Alamat ikut ditampilkan agar mudah dicek: server menyala? alamat benar?
          return 'Tidak bisa terhubung ke server (${DioClient.baseUrl}). '
              'Pastikan server menyala dan koneksi / Wi-Fi sekolah normal.';
        default:
          return 'Terjadi kesalahan jaringan.';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}