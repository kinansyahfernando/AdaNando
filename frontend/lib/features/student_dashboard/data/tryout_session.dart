import 'bank_lookup.dart';
import 'models/question.dart';
import 'models/session_result.dart';
import 'models/subtest.dart';
import 'models/tryout.dart';
import 'room_repository.dart' show ApiException;
import 'tryout_repository.dart';

/// Satu sesi Try Out Mandiri di HP: menyimpan soal tiap subtes, hasil, dan
/// sinkronisasi waktu dengan server. Waktu yang berlaku selalu waktu server.
class TryoutSession {
  TryoutSession({TryoutRepository? repository})
    : _repo = repository ?? TryoutRepository();

  final TryoutRepository _repo;

  late TryoutState state;

  /// Selisih jam server - jam HP.
  int _offsetMs = 0;

  final Map<int, List<Question>> _questions = {};

  /// Hasil per subtes (indeks subtes -> hasil). Subtes tanpa hasil = tidak dikerjakan.
  final Map<int, SessionResult> results = {};

  /// Diisi bila try out diakhiri dari HP: 'violation' | 'quit'.
  String? clientEndReason;

  List<TryoutSectionConfig> get sections => state.sections;

  String? get endReason => clientEndReason ?? state.endReason;

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  void _apply(TryoutState s, int requestStartMs) {
    final t1 = _nowMs();
    final localMid = (requestStartMs + t1) / 2;
    _offsetMs = (s.serverNow - localMid).round();
    state = s;
  }

  /// Mulai try out baru di server.
  Future<void> begin() async {
    final t0 = _nowMs();
    final s = await _repo.start();
    _apply(s, t0);
  }

  /// Sisa waktu subtes [index] (detik), berdasarkan jam server.
  int remainingSeconds(int index) {
    if (!state.isRunning || index != state.currentSection) return 0;
    final endsAt = state.sectionEndsAt;
    if (endsAt == null) return 0;
    final ms = endsAt - (_nowMs() + _offsetMs);
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  List<Question> questionsFor(int index) {
    return _questions.putIfAbsent(
      index,
      () => BankLookup.pickCycled(sections[index].id, sections[index].questions),
    );
  }

  Subtest subtestFor(int index) => BankLookup.subtestById(sections[index].id);

  SessionResult buildResult(int index, Map<int, int> answers) {
    return SessionResult(
      subtest: subtestFor(index),
      questions: questionsFor(index),
      answers: answers,
    );
  }

  /// Sinkron ulang waktu & status dengan server. Gagal = diabaikan.
  Future<void> sync() async {
    final t0 = _nowMs();
    try {
      final s = await _repo.fetch(state.attemptId);
      _apply(s, t0);
    } catch (_) {
      // Sinyal putus: lanjut memakai perhitungan waktu terakhir.
    }
  }

  /// Kumpulkan satu subtes. True bila selesai diproses (server menerima, atau
  /// menolak dengan alasan pasti). False bila gagal karena jaringan -> boleh dicoba lagi.
  Future<bool> submitSection(int index, SessionResult result) async {
    final t0 = _nowMs();
    try {
      final s = await _repo.submitSection(
        state.attemptId,
        sectionIndex: index,
        correct: result.correct,
        wrong: result.wrong,
      );
      _apply(s, t0);
      results[index] = result;
      return true;
    } on ApiException {
      results[index] = result;
      await sync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Akhiri seluruh try out lebih awal. Tidak pernah melempar error:
  /// hasil di HP tetap ditampilkan walau server tidak terjangkau.
  Future<void> finish({
    required String reason,
    required int index,
    required SessionResult result,
  }) async {
    clientEndReason = reason;
    results[index] = result;
    try {
      final t0 = _nowMs();
      final s = await _repo.finish(
        state.attemptId,
        reason: reason,
        sectionIndex: index,
        correct: result.correct,
        wrong: result.wrong,
      );
      _apply(s, t0);
    } catch (_) {
      // Server akan menutup sendiri saat waktu habis / try out baru dimulai.
    }
  }
}
