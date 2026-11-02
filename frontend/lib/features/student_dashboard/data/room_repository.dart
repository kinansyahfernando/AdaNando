import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/question.dart';
import 'models/room.dart';

/// Error dari backend (status 4xx) beserta pesan yang bisa langsung ditampilkan.
class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// Panggilan API fitur Belajar Bareng.
class RoomRepository {
  final Dio _dio = DioClient.instance;

  Future<RoomState> create({
    required String subtestId,
    required int count,
    required int durationSeconds,
  }) async {
    // Soal dipilih server dari bank soal; aplikasi hanya meminta jumlahnya.
    final response = await _dio.post(
      '/rooms',
      data: {
        'subtestId': subtestId,
        'count': count,
        'durationSeconds': durationSeconds,
      },
    );
    return RoomState.fromJson(_handle(response));
  }

  Future<RoomState> join(String code) async {
    final response = await _dio.post('/rooms/join', data: {'code': code});
    return RoomState.fromJson(_handle(response));
  }

  Future<RoomState> fetch(String code) async {
    final response = await _dio.get('/rooms/$code');
    return RoomState.fromJson(_handle(response));
  }

  Future<RoomState> start(String code) async {
    final response = await _dio.post('/rooms/$code/start');
    return RoomState.fromJson(_handle(response));
  }

  Future<RoomState> submit(
    String code, {
    required Map<String, int> answers,
  }) async {
    // Nilai dihitung server dari jawaban mentah ini.
    final response = await _dio.post(
      '/rooms/$code/submit',
      data: {'answers': answers},
    );
    return RoomState.fromJson(_handle(response));
  }

  /// Soal room (tanpa kunci), tersedia setelah room dimulai.
  Future<List<Question>> questions(String code) async {
    final data = _handle(await _dio.get('/rooms/$code/questions'));
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Question.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Soal + kunci + pembahasan, hanya setelah room selesai.
  Future<List<Question>> review(String code) async {
    final data = _handle(await _dio.get('/rooms/$code/review'));
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Question.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> leave(String code) async {
    final response = await _dio.post('/rooms/$code/leave');
    _handle(response);
  }

  /// validateStatus < 500 membuat 4xx tidak dilempar Dio,
  /// jadi di sini kita lempar sendiri dengan pesan dari backend.
  Map<String, dynamic> _handle(Response response) {
    final code = response.statusCode ?? 0;
    final data = response.data;

    if (code >= 200 && code < 300 && data is Map<String, dynamic>) {
      return data;
    }

    final message = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'Terjadi kesalahan (kode $code)';
    throw ApiException(message, code);
  }
}
