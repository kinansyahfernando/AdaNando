import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/room.dart';
import '../../data/room_repository.dart';

/// State room Belajar Bareng yang sedang diikuti.
/// Kondisi room diperbarui dengan polling ke server tiap 2 detik.
class RoomProvider extends ChangeNotifier {
  RoomProvider({RoomRepository? repository})
    : _repo = repository ?? RoomRepository();

  final RoomRepository _repo;

  RoomState? room;
  bool busy = false;
  String? error;

  /// True bila polling terakhir gagal (mis. sinyal putus).
  bool connectionProblem = false;

  Timer? _pollTimer;
  bool _fetching = false;
  bool _disposed = false;

  /// Selisih jam server - jam HP, supaya hitung mundur sama di semua HP.
  int _offsetMs = 0;

  static const Duration _pollInterval = Duration(seconds: 2);

  int get _serverNowMs => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  /// Sisa waktu ujian (detik), berdasarkan jam server.
  int get remainingSeconds {
    final endsAt = room?.endsAt;
    if (endsAt == null) return 0;
    final ms = endsAt - _serverNowMs;
    if (ms <= 0) return 0;
    return (ms / 1000).ceil();
  }

  // ───────────────────────── Aksi ─────────────────────────

  Future<bool> createRoom({
    required String subtestId,
    required List<String> questionIds,
    required int durationSeconds,
  }) async {
    final ok = await _run(
      () => _repo.create(
        subtestId: subtestId,
        questionIds: questionIds,
        durationSeconds: durationSeconds,
      ),
    );
    if (ok) startPolling();
    return ok;
  }

  Future<bool> joinRoom(String code) async {
    final ok = await _run(() => _repo.join(code.trim().toUpperCase()));
    if (ok) startPolling();
    return ok;
  }

  Future<bool> startRoom() async {
    final current = room;
    if (current == null) return false;
    return _run(() => _repo.start(current.code));
  }

  Future<bool> submitAnswers({
    required Map<String, int> answers,
    required int correct,
    required int wrong,
  }) async {
    final current = room;
    if (current == null) return false;
    return _run(
      () => _repo.submit(
        current.code,
        answers: answers,
        correct: correct,
        wrong: wrong,
      ),
    );
  }

  /// Keluar dari room lalu bersihkan state.
  Future<void> leave() async {
    final code = room?.code;
    if (code != null) {
      try {
        await _repo.leave(code);
      } catch (_) {
        // Abaikan: yang penting state lokal dibersihkan.
      }
    }
    reset();
  }

  /// Bersihkan state lokal tanpa memanggil server.
  void reset() {
    stopPolling();
    room = null;
    busy = false;
    error = null;
    connectionProblem = false;
    _offsetMs = 0;
    _notify();
  }

  // ───────────────────────── Polling ─────────────────────────

  void startPolling() {
    final current = room;
    if (current == null || current.isFinished || current.isClosed) return;
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => refresh());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    final current = room;
    if (current == null || _fetching || _disposed) return;

    _fetching = true;
    final t0 = DateTime.now().millisecondsSinceEpoch;
    try {
      final state = await _repo.fetch(current.code);
      _apply(state, t0);
      connectionProblem = false;
      _notify();
    } catch (e) {
      if (e is ApiException &&
          (e.statusCode == 403 || e.statusCode == 404)) {
        // Room hilang / kita bukan lagi peserta -> anggap ditutup.
        room = current.copyWithStatus('closed');
        stopPolling();
      } else {
        connectionProblem = true;
      }
      _notify();
    } finally {
      _fetching = false;
    }
  }

  // ───────────────────────── Internal ─────────────────────────

  Future<bool> _run(Future<RoomState> Function() action) async {
    busy = true;
    error = null;
    _notify();

    final t0 = DateTime.now().millisecondsSinceEpoch;
    try {
      final state = await action();
      _apply(state, t0);
      busy = false;
      _notify();
      return true;
    } catch (e) {
      busy = false;
      error = _readable(e);
      _notify();
      return false;
    }
  }

  void _apply(RoomState state, int requestStartMs) {
    final t1 = DateTime.now().millisecondsSinceEpoch;
    final localMid = (requestStartMs + t1) / 2;
    _offsetMs = (state.serverNow - localMid).round();
    room = state;
    if (state.isFinished || state.isClosed) stopPolling();
  }

  String _readable(Object e) {
    if (e is ApiException) return e.message;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Tidak bisa terhubung ke server. Periksa koneksi dan pastikan backend menyala.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
