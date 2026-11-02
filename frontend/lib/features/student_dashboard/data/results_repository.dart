import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/result_entry.dart';
import 'room_repository.dart' show ApiException;

/// Riwayat hasil latihan & try out (untuk halaman Potensi).
class ResultsRepository {
  final Dio _dio = DioClient.instance;

  /// Kirim jawaban satu sesi latihan; NILAI dihitung server, bukan dari aplikasi.
  /// Gagal menyimpan tidak boleh mengganggu siswa, jadi semua error diabaikan.
  Future<void> savePractice(List<({String questionId, int chosenIndex})> answers) async {
    if (answers.isEmpty) return;
    try {
      await _dio.post(
        '/practice/finish',
        data: {
          'answers': [
            for (final a in answers)
              {
                'questionId': int.tryParse(a.questionId) ?? 0,
                'chosenIndex': a.chosenIndex,
              },
          ],
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
