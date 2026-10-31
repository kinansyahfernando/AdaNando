// lib/core/network/dio_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DioClient {
  DioClient._();

  /// Token JWT. Isi setelah login: DioClient.setToken(token)
  static String? _token;
  static void setToken(String? token) => _token = token;
  static void clearToken() => _token = null;

  static String get baseUrl {
    // 1) Dari .env (kalau sudah di-load dan diisi)
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.maybeGet('API_BASE_URL');
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    }

    // 2) Default sesuai platform
    if (kIsWeb) return 'http://127.0.0.1:3000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1'; // Android Emulator
    }
    return 'http://127.0.0.1:3000/api/v1';
  }

  /// Singleton Dio, dibuat sekali saat pertama dipakai (lazy).
  static final Dio instance = _build();

  static Dio _build() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        // 4xx tidak dilempar sebagai exception, jadi pesan error backend bisa dibaca
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Tempel token otomatis di setiap request
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ),
    );

    if (kDebugMode) {
      debugPrint('🌐 DioClient baseUrl: ${dio.options.baseUrl}');
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          error: true,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }

    return dio;
  }
}