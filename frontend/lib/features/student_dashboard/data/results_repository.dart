import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/result_entry.dart';
import 'room_repository.dart' show ApiException;

/// Riwayat hasil latihan & try out (untuk halaman Potensi).
class ResultsRepository {
  final Dio _dio = DioClient.instance;

  /// Simpan hasil latihan satu subtes. Gagal menyimpan tidak boleh
  /// mengganggu siswa, jadi semua error diabaikan.
  Future<void> savePractice({
    required String subtestId,
    required int total,
    required int correct,
    required int wrong,
  }) async {
    if (total < 1) return;
    try {
      await _dio.post(
        '/results',
        data: {
          'subtestId': subtestId,
          'total': total,
          'correct': correct,
          'wrong': wrong,
        },
      );
    } catch (_) {
      // Abaikan.
    }
  }

  /// Seluruh riwayat, urut dari yang terlama ke terbaru.
  Future<List<ResultEntry>> history() async {
    final response = await _dio.get('/results/history');
    final code = response.statusCode ?? 0;
    final data = response.data;

    if (code >= 200 && code < 300 && data is Map<String, dynamic>) {
      final items = (data['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((m) => ResultEntry.fromJson(m.cast<String, dynamic>()))
          .toList();
    }

    final message = (data is Map && data['message'] != null)
        ? data['message'].toString()
        : 'Gagal memuat riwayat (kode $code)';
    throw ApiException(message, code);
  }
}
