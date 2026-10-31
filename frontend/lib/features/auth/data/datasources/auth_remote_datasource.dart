import '../../../../core/network/dio_client.dart';

class AuthRemoteDataSource {
  final _dio = DioClient.instance;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'role': 'admin', // Set default admin untuk tes
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}