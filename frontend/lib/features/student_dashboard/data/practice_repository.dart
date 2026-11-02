import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/question.dart';
import 'room_repository.dart' show ApiException;

/// Hasil pemeriksaan satu jawaban latihan oleh server.
class CheckResult {
  const CheckResult({
    required this.correct,
    required this.correctIndex,
    required this.explanation,
  });

  final bool correct;
  final int correctIndex;
  final String explanation;
}

/// True bila kegagalan karena aplikasi tidak bisa menjangkau server sama sekali
/// (server mati, alamat API salah, jaringan putus, timeout).
bool isConnectionError(Object error) {
  if (error is! DioException) return false;
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return true;
    default:
      return false;
  }
}

/// Ubah error teknis menjadi pesan yang menjelaskan PENYEBAB sebenarnya,
/// bukan hanya "gagal" — supaya mudah ditelusuri.
String friendlyError(Object error, {String fallback = 'Gagal memuat soal. Coba lagi.'}) {
  if (error is ApiException) return error.message;
  if (isConnectionError(error)) {
    return 'Tidak bisa terhubung ke server (${DioClient.baseUrl}). '
        'Pastikan backend sudah menyala, lalu coba lagi.';
  }
  if (error is DioException) {
    final data = error.response?.data;
    final code = error.response?.statusCode;
    final serverMessage = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : null;
    if (serverMessage != null) {
      return code == null ? serverMessage : '$serverMessage (kode $code)';
    }
    if (code != null) return 'Server bermasalah (kode $code). Periksa terminal backend.';
  }
  if (error is TypeError || error is FormatException) {
    return 'Data soal dari server tidak sesuai format yang diharapkan.';
  }
  return fallback;
}

/// Sumber soal latihan: server. Soal dikirim TANPA kunci; kunci + pembahasan
/// baru diberikan saat siswa menekan "Periksa".
abstract class PracticeRepository {
  Future<List<Question>> getQuestions(String subtestId, {int count = 10});

  Future<CheckResult> check(String questionId, int chosenIndex);
}

class ApiPracticeRepository implements PracticeRepository {
  final Dio _dio = DioClient.instance;

  Map<String, dynamic> _handle(Response response) {
    final code = response.statusCode ?? 0;
    final data = response.data;
    if (code >= 200 && code < 300 && data is Map<String, dynamic>) return data;
    final message = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'Terjadi kesalahan (kode $code)';
    throw ApiException(message, code);
  }

  @override
  Future<List<Question>> getQuestions(String subtestId, {int count = 10}) async {
    final response = await _dio.get(
      '/practice/questions',
      queryParameters: {'subtestId': subtestId, 'count': count},
    );
    final data = _handle(response);
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => Question.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<CheckResult> check(String questionId, int chosenIndex) async {
    final response = await _dio.post(
      '/practice/check',
      data: {
        'questionId': int.tryParse(questionId) ?? 0,
        'chosenIndex': chosenIndex,
      },
    );
    final data = _handle(response);
    return CheckResult(
      correct: data['correct'] == true,
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? -1,
      explanation: (data['explanation'] ?? '').toString(),
    );
  }
}
