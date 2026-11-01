int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Satu subtes dalam Try Out (susunan resmi dari server).
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

/// Keadaan Try Out terbaru dari server.
class TryoutState {
  const TryoutState({
    required this.attemptId,
    required this.status,
    required this.currentSection,
    required this.sectionEndsAt,
    required this.serverNow,
    required this.endReason,
    required this.sections,
  });

  final int attemptId;

  /// 'running' | 'finished'
  final String status;
  final int currentSection;

  /// Batas akhir subtes berjalan (ms epoch, jam server). Null bila selesai.
  final int? sectionEndsAt;
  final int serverNow;

  /// 'done' | 'timeout' | 'violation' | 'quit' | 'abandoned' | null
  final String? endReason;
  final List<TryoutSectionConfig> sections;

  bool get isRunning => status == 'running';
  bool get isFinished => status == 'finished';

  int get totalQuestions => sections.fold<int>(0, (sum, s) => sum + s.questions);

  factory TryoutState.fromJson(Map<String, dynamic> json) {
    final attempt =
        (json['attempt'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final sections = (json['sections'] as List?) ?? const [];

    return TryoutState(
      attemptId: _asInt(attempt['id']) ?? 0,
      status: (attempt['status'] ?? 'running').toString(),
      currentSection: _asInt(attempt['currentSection']) ?? 0,
      sectionEndsAt: _asInt(attempt['sectionEndsAt']),
      serverNow:
          _asInt(attempt['serverNow']) ?? DateTime.now().millisecondsSinceEpoch,
      endReason: attempt['endReason']?.toString(),
      sections: sections
          .whereType<Map>()
          .map((m) => TryoutSectionConfig.fromJson(m.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Susunan Try Out untuk tampilan sebelum mulai.
/// Angka resmi tetap berasal dari server saat try out dimulai.
class TryoutPlan {
  TryoutPlan._();

  static const List<TryoutPlanItem> items = [
    TryoutPlanItem('PU', 'Penalaran Umum', 30, '30'),
    TryoutPlanItem('PPU', 'Pengetahuan dan Pemahaman Umum', 20, '15'),
    TryoutPlanItem('PBM', 'Pemahaman Bacaan dan Menulis', 20, '25'),
    TryoutPlanItem('PK', 'Pengetahuan Kuantitatif', 20, '20'),
    TryoutPlanItem('LBI', 'Literasi Bahasa Indonesia', 30, '42,5'),
    TryoutPlanItem('LBE', 'Literasi Bahasa Inggris', 20, '20'),
    TryoutPlanItem('PM', 'Penalaran Matematika', 20, '42,5'),
  ];

  static const int totalQuestions = 160;
  static const int totalMinutes = 195;
}

class TryoutPlanItem {
  const TryoutPlanItem(this.code, this.name, this.questions, this.minutes);

  final String code;
  final String name;
  final int questions;
  final String minutes;
}
