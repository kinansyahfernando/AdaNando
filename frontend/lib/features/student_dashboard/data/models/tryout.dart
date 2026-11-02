import 'question.dart';

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Satu bagian / subtes dalam ujian (susunan resmi dari server).
class TryoutSectionConfig {
  const TryoutSectionConfig({
    required this.id,
    required this.name,
    required this.questions,
    required this.seconds,
  });

  final String id;
  final String name;
  final int questions;
  final int seconds;

  factory TryoutSectionConfig.fromJson(Map<String, dynamic> json) {
    return TryoutSectionConfig(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      questions: _asInt(json['questions']) ?? 0,
      seconds: _asInt(json['seconds']) ?? 0,
    );
  }
}

/// Nilai satu bagian, dihitung server.
class SectionScore {
  const SectionScore({
    required this.id,
    required this.name,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.points,
    required this.worked,
  });

  final String id;
  final String name;
  final int total;
  final int correct;
  final int wrong;
  final int points;

  /// False bila bagian ini tidak sempat dikerjakan.
  final bool worked;

  int get blank => total - correct - wrong;

  factory SectionScore.fromJson(Map<String, dynamic> json) {
    return SectionScore(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      total: _asInt(json['total']) ?? 0,
      correct: _asInt(json['correct']) ?? 0,
      wrong: _asInt(json['wrong']) ?? 0,
      points: _asInt(json['points']) ?? 0,
      worked: json['worked'] == true,
    );
  }
}

/// Nilai seluruh ujian (dari server).
class ExamScore {
  const ExamScore({
    required this.sections,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.points,
    required this.score,
  });

  final List<SectionScore> sections;
  final int total;
  final int correct;
  final int wrong;
  final int points;

  /// Skala 0-100 (benar / total).
  final double score;

  int get blank => total - correct - wrong;

  factory ExamScore.fromJson(Map<String, dynamic> json) {
    return ExamScore(
      sections: ((json['sections'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SectionScore.fromJson(m.cast<String, dynamic>()))
          .toList(),
      total: _asInt(json['total']) ?? 0,
      correct: _asInt(json['correct']) ?? 0,
      wrong: _asInt(json['wrong']) ?? 0,
      points: _asInt(json['points']) ?? 0,
      score: (json['score'] is num) ? (json['score'] as num).toDouble() : 0,
    );
  }
}

/// Keadaan ujian terbaru dari server.
class TryoutState {
  const TryoutState({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.kind,
    required this.status,
    required this.currentSection,
    required this.sectionEndsAt,
    required this.serverNow,
    required this.endReason,
    required this.violations,
    required this.maxViolations,
    required this.sections,
    required this.result,
    required this.reviewAvailable,
    this.ended = false,
    this.counted = false,
  });

  final int attemptId;
  final int examId;
  final String examTitle;

  /// 'tryout' (Try Out Mandiri) | 'sekolah' (ujian dari guru)
  final String kind;

  /// 'running' | 'finished'
  final String status;
  final int currentSection;

  /// Batas akhir subtes berjalan (ms epoch, jam server). Null bila selesai.
  final int? sectionEndsAt;
  final int serverNow;

  /// 'done' | 'timeout' | 'violation' | 'quit' | 'abandoned' | 'admin' | null
  final String? endReason;
  final int violations;
  final int maxViolations;
  final List<TryoutSectionConfig> sections;

  /// Nilai, hanya bila kebijakan ujian mengizinkan siswa melihatnya.
  final ExamScore? result;
  final bool reviewAvailable;

  /// Khusus respons laporan pelanggaran.
  final bool ended;
  final bool counted;

  bool get isRunning => status == 'running';
  bool get isFinished => status == 'finished';
  bool get isSchoolExam => kind == 'sekolah';

  int get totalQuestions => sections.fold<int>(0, (sum, s) => sum + s.questions);

  factory TryoutState.fromJson(Map<String, dynamic> json) {
    final attempt =
        (json['attempt'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final exam =
        (json['exam'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final sections = (exam['sections'] as List?) ?? const [];
    final result = (json['result'] as Map?)?.cast<String, dynamic>();

    return TryoutState(
      attemptId: _asInt(attempt['id']) ?? 0,
      examId: _asInt(exam['id']) ?? 0,
      examTitle: (exam['title'] ?? 'Ujian').toString(),
      kind: (exam['kind'] ?? 'sekolah').toString(),
      status: (attempt['status'] ?? 'running').toString(),
      currentSection: _asInt(attempt['currentSection']) ?? 0,
      sectionEndsAt: _asInt(attempt['sectionEndsAt']),
      serverNow:
          _asInt(attempt['serverNow']) ?? DateTime.now().millisecondsSinceEpoch,
      endReason: attempt['endReason']?.toString(),
      violations: _asInt(attempt['violations']) ?? 0,
      maxViolations: _asInt(attempt['maxViolations']) ?? 0,
      sections: sections
          .whereType<Map>()
          .map((m) => TryoutSectionConfig.fromJson(m.cast<String, dynamic>()))
          .toList(),
      result: result == null ? null : ExamScore.fromJson(result),
      reviewAvailable: json['reviewAvailable'] == true,
      ended: json['ended'] == true,
      counted: json['counted'] == true,
    );
  }
}

/// Satu ujian pada daftar "Ujian" siswa.
class ExamSummary {
  const ExamSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.startAt,
    required this.endAt,
    required this.phase,
    required this.totalQuestions,
    required this.totalSeconds,
    required this.sections,
    required this.requiresToken,
    required this.runningAttemptId,
    required this.lastAttemptId,
    required this.lastStatus,
    required this.canStart,
    this.maxViolations = 0,
  });

  final int id;
  final String title;
  final String? description;
  final String kind;
  final int? startAt;
  final int? endAt;

  /// 'open' | 'upcoming' | 'ended'
  final String phase;
  final int totalQuestions;
  final int totalSeconds;
  final int sections;
  final bool requiresToken;
  final int? runningAttemptId;
  final int? lastAttemptId;
  final String? lastStatus;
  final bool canStart;

  /// Jumlah kesempatan keluar layar / pindah tab sebelum ujian otomatis diakhiri.
  /// 0 = pelanggaran hanya dicatat.
  final int maxViolations;

  bool get isTryout => kind == 'tryout';
  bool get isRunning => runningAttemptId != null;

  factory ExamSummary.fromJson(Map<String, dynamic> json) {
    return ExamSummary(
      id: _asInt(json['id']) ?? 0,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      kind: (json['kind'] ?? 'sekolah').toString(),
      startAt: _asInt(json['startAt']),
      endAt: _asInt(json['endAt']),
      phase: (json['phase'] ?? 'open').toString(),
      totalQuestions: _asInt(json['totalQuestions']) ?? 0,
      totalSeconds: _asInt(json['totalSeconds']) ?? 0,
      sections: _asInt(json['sections']) ?? 0,
      requiresToken: json['requiresToken'] == true,
      runningAttemptId: _asInt(json['runningAttemptId']),
      lastAttemptId: _asInt(json['lastAttemptId']),
      lastStatus: json['lastStatus']?.toString(),
      canStart: json['canStart'] == true,
      maxViolations: _asInt(json['maxViolations']) ?? 0,
    );
  }
}

/// Soal bagian yang sedang berjalan (tanpa kunci jawaban).
class SectionData {
  const SectionData({
    required this.sectionIndex,
    required this.subtestId,
    required this.subtestName,
    required this.questions,
    required this.answers,
    required this.endsAt,
    required this.serverNow,
  });

  final int sectionIndex;
  final String subtestId;
  final String subtestName;
  final List<Question> questions;

  /// Jawaban yang sudah tersimpan di server: indeks soal -> indeks pilihan.
  final Map<int, int> answers;
  final int endsAt;
  final int serverNow;

  factory SectionData.fromJson(Map<String, dynamic> json) {
    final subtest =
        (json['subtest'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final subtestId = (subtest['id'] ?? '').toString();
    final answers = <int, int>{};
    ((json['answers'] as Map?) ?? const {}).forEach((k, v) {
      final pos = int.tryParse('$k');
      final val = _asInt(v);
      if (pos != null && val != null && val >= 0) answers[pos] = val;
    });
    final list = (json['questions'] as List?) ?? const [];
    return SectionData(
      sectionIndex: _asInt(json['sectionIndex']) ?? 0,
      subtestId: subtestId,
      subtestName: (subtest['name'] ?? '').toString(),
      questions: [
        for (var i = 0; i < list.length; i++)
          Question.fromJson(
            {...(list[i] as Map).cast<String, dynamic>(), 'id': '$subtestId-$i'},
            subtestId: subtestId,
          ),
      ],
      answers: answers,
      endsAt: _asInt(json['endsAt']) ?? 0,
      serverNow:
          _asInt(json['serverNow']) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Pembahasan satu bagian (setelah server mengizinkan).
class ReviewSection {
  const ReviewSection({
    required this.id,
    required this.name,
    required this.questions,
    required this.answers,
  });

  final String id;
  final String name;

  /// Soal lengkap dengan kunci + pembahasan.
  final List<Question> questions;

  /// indeks soal -> pilihan siswa
  final Map<int, int> answers;

  factory ReviewSection.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final items = (json['items'] as List?) ?? const [];
    final questions = <Question>[];
    final answers = <int, int>{};
    for (var i = 0; i < items.length; i++) {
      final m = (items[i] as Map).cast<String, dynamic>();
      questions.add(
        Question.fromJson({
          ...m,
          'id': '$id-$i',
          'correctIndex': _asInt(m['correct']),
        }, subtestId: id),
      );
      final chosen = _asInt(m['chosen']);
      if (chosen != null) answers[i] = chosen;
    }
    return ReviewSection(
      id: id,
      name: (json['name'] ?? '').toString(),
      questions: questions,
      answers: answers,
    );
  }
}
