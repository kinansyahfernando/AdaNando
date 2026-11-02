import 'bank_lookup.dart';
import 'models/session_result.dart';
import 'models/subtest.dart';
import 'models/tryout.dart';
import 'room_repository.dart' show ApiException;
import 'tryout_repository.dart';

/// Satu sesi ujian di perangkat siswa. Semua yang menentukan nilai ada di
/// server: soal dikirim per bagian tanpa kunci, jawaban disimpan ke server,
/// nilai dihitung server. Waktu yang berlaku selalu jam server.
class TryoutSession {
  TryoutSession({TryoutRepository? repository})
    : _repo = repository ?? TryoutRepository();

  final TryoutRepository _repo;

  late TryoutState state;

  /// Selisih jam server - jam perangkat.
  int _offsetMs = 0;

  final Map<int, SectionData> _sections = {};

  /// Hasil per bagian untuk halaman hasil (diisi oleh [loadResults]).
  final Map<int, SessionResult> results = {};

  /// Daftar pembahasan per bagian (bila server mengizinkan).
  List<ReviewSection> reviews = const [];
  bool resultsLoaded = false;

  List<TryoutSectionConfig> get sections => state.sections;

  String? get endReason => state.endReason;

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  void _apply(TryoutState s, int requestStartMs) {
    final t1 = _nowMs();
    final localMid = (requestStartMs + t1) / 2;
    _offsetMs = (s.serverNow - localMid).round();
    state = s;
  }

  /// Mulai (atau lanjutkan) ujian di server.
  Future<void> begin(int examId, {String? token}) async {
    final t0 = _nowMs();
    final s = await _repo.start(examId, token: token);
    _apply(s, t0);
  }

  /// Lanjutkan percobaan yang masih berjalan.
  Future<void> resume(int attemptId) async {
    final t0 = _nowMs();
    final s = await _repo.fetch(attemptId);
    _apply(s, t0);
  }

  /// Sisa waktu bagian [index] (detik), berdasarkan jam server.
  int remainingSeconds(int index) {
    if (!state.isRunning || index != state.currentSection) return 0;
    final endsAt = state.sectionEndsAt;
    if (endsAt == null) return 0;
    final ms = endsAt - (_nowMs() + _offsetMs);
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Ambil soal bagian yang sedang berjalan dari server.
  Future<SectionData> loadSection(int index) async {
    final cached = _sections[index];
    if (cached != null) return cached;
    final t0 = _nowMs();
    final data = await _repo.section(state.attemptId);
    final t1 = _nowMs();
    _offsetMs = (data.serverNow - (t0 + t1) / 2).round();
    _sections[data.sectionIndex] = data;
    return data;
  }

  Subtest subtestFor(int index) {
    final sec = sections[index];
    return BankLookup.forSection(sec.id, sec.name);
  }

  /// Simpan jawaban sementara ke server (autosave). Gagal = diabaikan,
  /// jawaban lengkap tetap dikirim saat bagian dikumpulkan.
  Future<void> autosave(int index, Map<int, int> answers) async {
    try {
      await _repo.saveAnswers(
        state.attemptId,
        sectionIndex: index,
        answers: answers,
      );
    } catch (_) {
      // Sinyal putus: coba lagi pada perubahan jawaban berikutnya.
    }
  }

  /// Sinkron ulang waktu & status dengan server (sekaligus "detak jantung"
  /// yang memberi tahu pengawas bahwa siswa masih terhubung).
  Future<void> sync() async {
    final t0 = _nowMs();
    try {
      final s = await _repo.fetch(state.attemptId);
      _apply(s, t0);
    } catch (_) {
      // Sinyal putus: lanjut memakai perhitungan waktu terakhir.
    }
  }

  /// Kumpulkan satu bagian. True bila server memprosesnya; false bila gagal
  /// karena jaringan (boleh dicoba lagi).
  Future<bool> submitSection(int index, Map<int, int> answers) async {
    final t0 = _nowMs();
    try {
      final s = await _repo.submitSection(
        state.attemptId,
        sectionIndex: index,
        answers: answers,
      );
      _apply(s, t0);
      return true;
    } on ApiException {
      await sync(); // ditolak server (mis. waktu habis): ikuti status server
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Siswa memilih keluar. Tidak pernah melempar error.
  Future<void> finish({
    required int index,
    required Map<int, int> answers,
  }) async {
    try {
      final t0 = _nowMs();
      final s = await _repo.finish(
        state.attemptId,
        sectionIndex: index,
        answers: answers,
      );
      _apply(s, t0);
    } catch (_) {
      await sync();
    }
  }

  /// Laporkan pelanggaran. Null = jaringan gagal (akan dicoba lagi).
  Future<TryoutState?> reportViolation({
    required String type,
    required int index,
    required Map<int, int> answers,
  }) async {
    try {
      final t0 = _nowMs();
      final s = await _repo.violation(
        state.attemptId,
        type: type,
        sectionIndex: index,
        answers: answers,
      );
      _apply(s, t0);
      return s;
    } catch (_) {
      return null;
    }
  }

  /// Muat nilai + pembahasan untuk halaman hasil.
  Future<void> loadResults() async {
    final t0 = _nowMs();
    final s = await _repo.fetch(state.attemptId);
    _apply(s, t0);

    results.clear();
    reviews = const [];

    if (state.reviewAvailable) {
      try {
        reviews = await _repo.review(state.attemptId);
      } catch (_) {
        reviews = const [];
      }
    }

    final score = state.result;
    for (var i = 0; i < sections.length; i++) {
      final sub = subtestFor(i);
      final review = i < reviews.length ? reviews[i] : null;
      final sc = (score != null && i < score.sections.length)
          ? score.sections[i]
          : null;
      if (sc != null && !sc.worked && review == null) continue; // tidak dikerjakan
      if (review != null) {
        results[i] = SessionResult(
          subtest: sub,
          questions: review.questions,
          answers: review.answers,
          fixedTotal: sc?.total,
          fixedCorrect: sc?.correct,
          fixedWrong: sc?.wrong,
        );
      } else if (sc != null) {
        results[i] = SessionResult(
          subtest: sub,
          questions: const [],
          answers: const {},
          fixedTotal: sc.total,
          fixedCorrect: sc.correct,
          fixedWrong: sc.wrong,
        );
      }
    }
    resultsLoaded = true;
  }
}
