import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/tryout.dart';
import 'room_repository.dart' show ApiException;

/// Panggilan API ujian (Try Out Mandiri dan ujian sekolah).
/// Soal & kunci dikelola server; aplikasi hanya mengirim jawaban mentah.
class TryoutRepository {
  final Dio _dio = DioClient.instance;

  Future<List<ExamSummary>> listExams() async {
    final data = _handle(await _dio.get('/exams'));
    return ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => ExamSummary.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Future<TryoutState> start(int examId, {String? token}) async {
    final response = await _dio.post(
      '/exams/$examId/start',
      data: {if (token != null && token.isNotEmpty) 'token': token},
    );
    return TryoutState.fromJson(_handle(response));
  }

  Future<TryoutState> fetch(int attemptId) async {
    final response = await _dio.get('/attempts/$attemptId');
    return TryoutState.fromJson(_handle(response));
  }

  Future<SectionData> section(int attemptId) async {
    final response = await _dio.get('/attempts/$attemptId/section');
    return SectionData.fromJson(_handle(response));
  }

  Future<void> saveAnswers(
    int attemptId, {
    required int sectionIndex,
    required Map<int, int> answers,
  }) async {
    final response = await _dio.put(
      '/attempts/$attemptId/answers',
      data: {'sectionIndex': sectionIndex, 'answers': _keys(answers)},
    );
    _handle(response);
  }

  Future<TryoutState> submitSection(
    int attemptId, {
    required int sectionIndex,
    required Map<int, int> answers,
  }) async {
    final response = await _dio.post(
      '/attempts/$attemptId/submit-section',
      data: {'sectionIndex': sectionIndex, 'answers': _keys(answers)},
    );
    return TryoutState.fromJson(_handle(response));
  }

  Future<TryoutState> finish(
    int attemptId, {
    required int sectionIndex,
    required Map<int, int> answers,
  }) async {
    final response = await _dio.post(
      '/attempts/$attemptId/finish',
      data: {'sectionIndex': sectionIndex, 'answers': _keys(answers)},
    );
    return TryoutState.fromJson(_handle(response));
  }

  Future<TryoutState> violation(
    int attemptId, {
    required String type,
    required int sectionIndex,
    required Map<int, int> answers,
  }) async {
    final response = await _dio.post(
      '/attempts/$attemptId/violation',
      data: {
        'type': type,
        'sectionIndex': sectionIndex,
        'answers': _keys(answers),
      },
    );
    return TryoutState.fromJson(_handle(response));
  }

  Future<List<ReviewSection>> review(int attemptId) async {
    final data = _handle(await _dio.get('/attempts/$attemptId/review'));
    return ((data['sections'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => ReviewSection.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  Map<String, int> _keys(Map<int, int> answers) => {
    for (final e in answers.entries) '${e.key}': e.value,
  };

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
