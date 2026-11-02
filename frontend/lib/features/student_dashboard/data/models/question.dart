/// Satu soal pilihan ganda (A-E).
///
/// Selama ujian, kunci jawaban TIDAK ada di aplikasi: [correctIndex] bernilai -1
/// dan [explanation] kosong. Keduanya baru terisi setelah server mengizinkan
/// (hasil / pembahasan), lewat [withKey].
class Question {
  const Question({
    required this.id,
    required this.subtestId,
    required this.text,
    required this.options,
    this.correctIndex = -1,
    this.explanation = '',
    this.passage,
  });

  final String id;
  final String subtestId;

  /// Teks bacaan (opsional) untuk soal berbasis wacana.
  final String? passage;

  final String text;
  final List<String> options;

  /// Indeks jawaban benar (0 = A, 1 = B, dst). -1 = belum diketahui.
  final int correctIndex;

  /// Pembahasan (kosong selama kunci belum dibuka server).
  final String explanation;

  bool get hasKey => correctIndex >= 0;

  /// 0 -> 'A', 1 -> 'B', dst.
  static String labelOf(int index) => String.fromCharCode(65 + index);

  String get correctLabel => hasKey ? labelOf(correctIndex) : '-';

  Question withKey({required int correctIndex, required String explanation}) {
    return Question(
      id: id,
      subtestId: subtestId,
      text: text,
      options: options,
      passage: passage,
      correctIndex: correctIndex,
      explanation: explanation,
    );
  }

  factory Question.fromJson(Map<String, dynamic> json, {String? subtestId}) {
    return Question(
      id: (json['id'] ?? '').toString(),
      subtestId: (json['subtestId'] ?? subtestId ?? '').toString(),
      passage: json['passage']?.toString(),
      text: (json['text'] ?? '').toString(),
      options: ((json['options'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      correctIndex: json['correctIndex'] is int
          ? json['correctIndex'] as int
          : (json['correct'] is int ? json['correct'] as int : -1),
      explanation: (json['explanation'] ?? '').toString(),
    );
  }
}
