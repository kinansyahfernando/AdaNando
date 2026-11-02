// lib/core/network/dio_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DioClient {
  DioClient._();

  /// Token JWT. Diisi setelah login: DioClient.setToken(token)
  static String? _token;
  static void setToken(String? token) => _token = token;
  static void clearToken() => _token = null;

  /// Token saat ini (dipakai untuk masuk otomatis ke panel web admin).
  static String? get token => _token;

  /// Dipanggil saat server menolak token (sesi habis / login di perangkat lain /
  /// akun dinonaktifkan). Diisi oleh AuthProvider.
  static void Function(String message)? onUnauthorized;

  static String get baseUrl {
    // Web versi rilis (dilayani oleh server yang sama): selalu satu alamat dengan API.
    if (kIsWeb && kReleaseMode) return '${Uri.base.origin}/api/v1';

    // Development / aplikasi HP: pakai .env bila diisi
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.maybeGet('API_BASE_URL');
      if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
    }

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
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        // 4xx tidak dilempar sebagai exception, jadi pesan error backend bisa dibaca
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          // 401 selain di layar login = sesi dicabut server
          final isLogin = response.requestOptions.path.contains('/auth/login');
          if (response.statusCode == 401 && !isLogin && _token != null) {
            final data = response.data;
            final msg = (data is Map && data['message'] != null)
                ? data['message'].toString()
                : 'Sesi berakhir. Silakan login ulang.';
            onUnauthorized?.call(msg);
          }
          handler.next(response);
        },
      ),
    );

    if (kDebugMode) {
      debugPrint('🌐 DioClient baseUrl: ${dio.options.baseUrl}');
      // Body tidak dicatat agar password / token tidak muncul di log.
      dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          error: true,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }

    return dio;
  }
}