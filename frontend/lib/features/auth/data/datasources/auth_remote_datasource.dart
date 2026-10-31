import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class AuthRemoteDataSource {
  final Dio _dio = DioClient.instance;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _handle(response);
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    // Role tidak dikirim. Pendaftaran publik otomatis jadi siswa di backend.
    final response = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    return _handle(response);
  }

  /// Karena validateStatus < 500, status 4xx tidak dilempar Dio.
  /// Di sini kita lempar sendiri dengan pesan dari backend.
  Map<String, dynamic> _handle(Response response) {
    final code = response.statusCode ?? 0;
    final data = response.data;

    if (code >= 200 && code < 300 && data is Map<String, dynamic>) {
      return data;
    }

    final message = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'Terjadi kesalahan (kode $code)';
    throw Exception(message);
  }
}