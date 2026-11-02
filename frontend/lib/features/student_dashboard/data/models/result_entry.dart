/// Satu hasil latihan subtes atau subtes dalam Try Out (untuk halaman Potensi).
class ResultEntry {
  const ResultEntry({
    required this.id,
    required this.subtestId,
    required this.source,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.points,
    required this.createdAt,
  });

  final int id;
  final String subtestId;

  /// 'latihan' | 'tryout' | 'ujian'
  final String source;
  final int total;
  final int correct;
  final int wrong;
  final int points;

  /// Milidetik epoch.
  final int createdAt;

  int get blank => total - correct - wrong;
  double get accuracy => total == 0 ? 0 : correct / total;
  bool get isTryout => source == 'tryout' || source == 'ujian';
  DateTime get date => DateTime.fromMillisecondsSinceEpoch(createdAt);

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  factory ResultEntry.fromJson(Map<String, dynamic> json) {
    return ResultEntry(
      id: _int(json['id']),
      subtestId: (json['subtestId'] ?? '').toString(),
      source: (json['source'] ?? 'latihan').toString(),
      total: _int(json['total']),
      correct: _int(json['correct']),
      wrong: _int(json['wrong']),
      points: _int(json['points']),
      createdAt: _int(json['createdAt']),
    );
  }
}
