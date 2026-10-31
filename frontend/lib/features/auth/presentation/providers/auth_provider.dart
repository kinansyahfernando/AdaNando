import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/auth_remote_datasource.dart';

class AuthProvider extends ChangeNotifier {
  final _authDataSource = AuthRemoteDataSource();

  bool isLoading = false;
  String? errorMessage;
  String? userRole; // 'admin' / 'siswa'
  String? userName;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _authDataSource.login(email, password);

      // Bentuk respons backend: { message, token, user: { id, name, email, role } }
      final token = response['token'] as String?;
      final user = response['user'] as Map<String, dynamic>?;
      if (token == null || user == null) {
        throw Exception('Format respons server tidak valid');
      }

      DioClient.setToken(token);
      userRole = user['role']?.toString();
      userName = user['name']?.toString();

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

  void logout() {
    DioClient.clearToken();
    userRole = null;
    userName = null;
    notifyListeners();
  }

  String _readableError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return 'Tidak bisa terhubung ke server. Pastikan backend menyala.';
        default:
          return 'Terjadi kesalahan jaringan.';
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}