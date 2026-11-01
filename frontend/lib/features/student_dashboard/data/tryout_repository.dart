import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import 'models/tryout.dart';
import 'room_repository.dart' show ApiException;

/// Panggilan API Try Out Mandiri.
class TryoutRepository {
  final Dio _dio = DioClient.instance;

  Future<TryoutState> start() async {
    final response = await _dio.post('/tryout/start');
    return TryoutState.fromJson(_handle(response));
  }

  Future<TryoutState> fetch(int attemptId) async {
    final response = await _dio.get('/tryout/$attemptId');
    return TryoutState.fromJson(_handle(response));
  }

  Future<TryoutState> submitSection(
    int attemptId, {
    required int sectionIndex,
    required int correct,
    required int wrong,
  }) async {
    final response = await _dio.post(
      '/tryout/$attemptId/submit-section',
      data: {'sectionIndex': sectionIndex, 'correct': correct, 'wrong': wrong},
    );
    return TryoutState.fromJson(_handle(response));
  }

  Future<TryoutState> finish(
    int attemptId, {
    required String reason,
    int? sectionIndex,
    int? correct,
    int? wrong,
  }) async {
    final response = await _dio.post(
      '/tryout/$attemptId/finish',
      data: {
        'reason': reason,
        if (sectionIndex != null) 'sectionIndex': sectionIndex,
        if (correct != null) 'correct': correct,
        if (wrong != null) 'wrong': wrong,
      },
    );
    return TryoutState.fromJson(_handle(response));
  }

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
