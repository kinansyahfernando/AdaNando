/// Satu soal pilihan ganda (A-E).
class Question {
  const Question({
    required this.id,
    required this.subtestId,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.passage,
  });

  final String id;
  final String subtestId;

  /// Teks bacaan (opsional) untuk soal berbasis wacana.
  final String? passage;

  final String text;
  final List<String> options;

  /// Indeks jawaban benar (0 = A, 1 = B, dst).
  final int correctIndex;

  /// Pembahasan yang tampil setelah siswa memeriksa jawaban.
  final String explanation;

  /// 0 -> 'A', 1 -> 'B', dst.
  static String labelOf(int index) => String.fromCharCode(65 + index);

  String get correctLabel => labelOf(correctIndex);
}
