import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/security/exam_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/question.dart';
import '../../data/models/subtest.dart';
import '../widgets/option_tile.dart';
import '../widgets/section_card.dart';

/// Jawaban server atas laporan pelanggaran.
class ViolationOutcome {
  const ViolationOutcome({
    required this.counted,
    required this.count,
    required this.max,
    required this.ended,
    this.route,
  });

  /// True bila pelanggaran ini menambah hitungan.
  final bool counted;
  final int count;
  final int max;

  /// True bila server mengakhiri ujian karena batas terlampaui.
  final bool ended;
  final Route<void>? route;
}

/// Halaman ujian berwaktu. Dipakai oleh Try Out Mandiri dan Belajar Bareng.
///
/// - Siswa bebas pindah soal dan mengubah jawaban sampai waktu habis.
/// - Kunci jawaban & pembahasan baru muncul di halaman hasil.
/// - Saat waktu habis, jawaban otomatis dikumpulkan.
class TimedQuizPage extends StatefulWidget {
  const TimedQuizPage({
    super.key,
    required this.title,
    required this.subtest,
    required this.questions,
    required this.remainingSeconds,
    required this.onFinish,
    this.onLeave,
    this.strict = false,
    this.onViolation,
    this.leaveWarning,
    this.initialAnswers = const {},
    this.onAnswersChanged,
    this.onViolationEvent,
    this.watermark,
  });

  final String title;
  final Subtest subtest;
  final List<Question> questions;

  /// Mengembalikan sisa waktu (detik) saat ini.
  final int Function() remainingSeconds;

  /// Dipanggil saat jawaban dikumpulkan. Kembalikan route halaman hasil bila
  /// berhasil, atau null bila gagal (siswa akan diberi pilihan coba lagi).
  final Future<Route<void>?> Function(Map<int, int> answers) onFinish;

  /// Dipanggil saat siswa memilih keluar tanpa mengumpulkan.
  final VoidCallback? onLeave;

  /// Mode ketat (Try Out Mandiri): meninggalkan aplikasi / pindah tab
  /// langsung mengakhiri ujian lewat [onViolation].
  final bool strict;

  /// Mengakhiri ujian lebih awal. [reason]: 'violation' (keluar aplikasi) atau
  /// 'quit' (siswa memilih keluar). Kembalikan route halaman hasil.
  final Future<Route<void>?> Function(Map<int, int> answers, String reason)?
  onViolation;

  /// Teks peringatan saat siswa menekan tombol keluar.
  final String? leaveWarning;

  /// Jawaban yang sudah tersimpan di server (melanjutkan setelah HP mati / refresh).
  final Map<int, int> initialAnswers;

  /// Dipanggil (dengan jeda singkat) setiap jawaban berubah, untuk autosave ke server.
  final void Function(Map<int, int> answers)? onAnswersChanged;

  /// Melaporkan pelanggaran ke server (pindah tab/aplikasi, keluar layar penuh, dll).
  /// SERVER yang memutuskan apakah ujian diakhiri. Kembalikan null bila jaringan gagal.
  final Future<ViolationOutcome?> Function(
    String type,
    Map<int, int> answers,
  )?
  onViolationEvent;

  /// Teks tanda air di atas soal (nama + NIS) supaya foto layar bisa dilacak.
  final String? watermark;

  @override
  State<TimedQuizPage> createState() => _TimedQuizPageState();
}

class _TimedQuizPageState extends State<TimedQuizPage>
    with WidgetsBindingObserver {
  Timer? _ticker;
  late int _remaining;
  int _index = 0;
  final Map<int, int> _answers = {};
  bool _submitting = false;
  bool _autoSubmitted = false;
  bool _ended = false;
  Timer? _saveTimer;
  bool _warningOpen = false;
  bool _pendingBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _answers.addAll(widget.initialAnswers);
    if (widget.strict) {
      WakelockPlus.enable().catchError((_) {}); // layar tidak mati saat ujian
      if (widget.onViolationEvent != null) {
        ExamGuard.start((type) => _reportViolation(type));
      }
    }
    _remaining = widget.remainingSeconds();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (_remaining <= 0 && widget.questions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoSubmit());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveTimer?.cancel();
    if (widget.strict) {
      ExamGuard.stop();
      WakelockPlus.disable().catchError((_) {});
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.strict) return;
    // Pindah aplikasi / layar dikunci = meninggalkan ujian.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (widget.onViolationEvent != null) {
        _reportViolation('app_background');
      } else {
        _endEarly('violation');
      }
    } else if (state == AppLifecycleState.resumed && _pendingBackground) {
      // Laporan saat di latar belakang gagal terkirim: kirim ulang sekarang.
      _pendingBackground = false;
      _reportViolation('app_background');
    }
  }

  /// Melapor ke server. Server mendebounce kejadian kembar dan memutuskan
  /// kapan ujian diakhiri; aplikasi hanya menampilkan peringatannya.
  Future<void> _reportViolation(String type) async {
    final handler = widget.onViolationEvent;
    if (handler == null || _ended || _submitting || !mounted) return;

    _saveTimer?.cancel();
    final outcome = await handler(type, Map<int, int>.of(_answers));
    if (!mounted || _ended) return;

    if (outcome == null) {
      if (type == 'app_background') _pendingBackground = true;
      return;
    }
    if (outcome.ended) {
      _ended = true;
      _ticker?.cancel();
      final route = outcome.route;
      if (route != null) {
        _replaceWith(route);
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    if (outcome.counted) _showViolationWarning(outcome.count, outcome.max);
  }

  Future<void> _showViolationWarning(int count, int max) async {
    if (_warningOpen || !mounted) return;
    _warningOpen = true;
    final left = max - count;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.danger,
          size: 40,
        ),
        title: Text('Peringatan $count dari $max'),
        content: Text(
          'Kamu meninggalkan layar ujian. Tetaplah di halaman ini. '
          '${left > 0 ? 'Sisa kesempatan: $left. Bila habis, ujian otomatis dikumpulkan dan diakhiri.' : ''}'
          '\n\nPelanggaran dicatat dan bisa dilihat guru / pengawas.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Saya mengerti'),
          ),
        ],
      ),
    );
    _warningOpen = false;
  }

  /// Pindah ke halaman berikutnya. Dialog / sheet yang masih terbuka
  /// (mis. saat waktu habis) ditutup dulu supaya halaman ujian ikut tergantikan.
  void _replaceWith(Route<void> route) {
    final navigator = Navigator.of(context);
    final self = ModalRoute.of(context);
    if (self != null) navigator.popUntil((r) => r == self);
    navigator.pushReplacement(route);
  }

  /// Mengakhiri seluruh ujian sekarang (mode ketat).
  Future<void> _endEarly(String reason) async {
    final handler = widget.onViolation;
    if (handler == null || _submitting || _ended || !mounted) return;

    _ended = true;
    _ticker?.cancel();
    setState(() => _submitting = true);

    final route = await handler(Map<int, int>.of(_answers), reason);
    if (!mounted) return;

    if (route != null) {
      _replaceWith(route);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _tick() {
    if (!mounted || _ended) return;
    final r = widget.remainingSeconds();
    setState(() => _remaining = r);
    if (r <= 0) _autoSubmit();
  }

  void _autoSubmit() {
    if (_autoSubmitted || !mounted) return;
    _autoSubmitted = true;
    _submit();
  }

  Future<void> _submit() async {
    if (_submitting || _ended) return;
    setState(() => _submitting = true);

    final route = await widget.onFinish(Map<int, int>.of(_answers));
    if (!mounted) return;

    if (route != null) {
      _ticker?.cancel();
      _replaceWith(route);
      return;
    }

    setState(() => _submitting = false);
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gagal mengirim jawaban'),
        content: const Text(
          'Periksa koneksi internetmu, lalu coba kirim lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keluar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (retry == true) {
      _submit();
    } else if (widget.strict && widget.onViolation != null) {
      _endEarly('quit');
    } else {
      widget.onLeave?.call();
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmSubmit() async {
    final total = widget.questions.length;
    final answered = _answers.length;
    final blank = total - answered;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kumpulkan jawaban?'),
        content: Text(
          blank > 0
              ? 'Kamu baru menjawab $answered dari $total soal. '
                    '$blank soal kosong tidak mendapat poin.'
              : 'Semua soal sudah terjawab. Jawaban tidak bisa diubah setelah dikumpulkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Periksa Lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Kumpulkan'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) _submit();
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari ujian?'),
        content: Text(
          widget.leaveWarning ??
              'Jawabanmu tidak akan dikumpulkan dan hasilnya tidak tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Lanjut Mengerjakan'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (leave != true || !mounted) return;
    if (widget.strict && widget.onViolation != null) {
      _endEarly('quit');
      return;
    }
    _ticker?.cancel();
    widget.onLeave?.call();
    Navigator.of(context).pop();
  }

  void _toggleAnswer(int optionIndex) {
    setState(() {
      if (_answers[_index] == optionIndex) {
        _answers.remove(_index); // tekan lagi untuk batal memilih
      } else {
        _answers[_index] = optionIndex;
      }
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    final cb = widget.onAnswersChanged;
    if (cb == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 700),
      () => cb(Map<int, int>.of(_answers)),
    );
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.questions.length) return;
    setState(() => _index = index);
  }

  Future<void> _openQuestionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Daftar Soal',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              _QuestionGrid(
                count: widget.questions.length,
                current: _index,
                isAnswered: _answers.containsKey,
                color: widget.subtest.color,
                onTap: (i) {
                  Navigator.of(sheetContext).pop();
                  _goTo(i);
                },
              ),
              const SizedBox(height: 12),
              const _GridLegend(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _confirmSubmit();
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Kumpulkan Jawaban'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(int seconds) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined, size: 56, color: AppColors.muted),
                const SizedBox(height: 12),
                const Text(
                  'Soal untuk sesi ini tidak ditemukan.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    widget.onLeave?.call();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= Breakpoints.medium;
    final total = widget.questions.length;
    final lowTime = _remaining <= 60;
    final color = widget.subtest.color;

    final questionArea = Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey<int>(_index),
            padding: EdgeInsets.fromLTRB(
              horizontalPagePadding(context),
              16,
              horizontalPagePadding(context),
              24,
            ),
            child: ContentWidth(
              maxWidth: 820,
              child: _QuestionBody(
                question: widget.questions[_index],
                number: _index + 1,
                total: total,
                color: color,
                selectedIndex: _answers[_index],
                showListButton: !wide,
                onListPressed: _openQuestionSheet,
                onSelect: _toggleAnswer,
              ),
            ),
          ),
        ),
        _BottomBar(
          isFirst: _index == 0,
          isLast: _index == total - 1,
          color: color,
          answered: _answers.length,
          total: total,
          onPrev: () => _goTo(_index - 1),
          onNext: () => _goTo(_index + 1),
          onSubmit: _confirmSubmit,
        ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_submitting) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Keluar',
            onPressed: _submitting ? null : _confirmLeave,
          ),
          title: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (lowTime ? AppColors.danger : color).withAlpha(28),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: lowTime ? AppColors.danger : color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _format(_remaining),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: lowTime ? AppColors.danger : color,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : _answers.length / total,
              minHeight: 4,
              backgroundColor: AppColors.border,
              color: color,
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: questionArea),
                      Container(
                        width: 300,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          border: Border(
                            left: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: SafeArea(
                          left: false,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Daftar Soal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _QuestionGrid(
                                  count: total,
                                  current: _index,
                                  isAnswered: _answers.containsKey,
                                  color: color,
                                  onTap: _goTo,
                                ),
                                const SizedBox(height: 14),
                                const _GridLegend(),
                                const SizedBox(height: 20),
                                OutlinedButton.icon(
                                  onPressed: _confirmSubmit,
                                  icon: const Icon(Icons.send_rounded),
                                  label: const Text('Kumpulkan Jawaban'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : questionArea,
            if (widget.watermark != null)
              Positioned.fill(child: _Watermark(text: widget.watermark!)),
            if (_submitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 14),
                            Text('Mengumpulkan jawaban…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Isi soal ─────────────────────────

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
    required this.question,
    required this.number,
    required this.total,
    required this.color,
    required this.selectedIndex,
    required this.showListButton,
    required this.onListPressed,
    required this.onSelect,
  });

  final Question question;
  final int number;
  final int total;
  final Color color;
  final int? selectedIndex;
  final bool showListButton;
  final VoidCallback onListPressed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final passage = question.passage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withAlpha(28),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Soal $number dari $total',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const Spacer(),
            if (showListButton)
              TextButton.icon(
                onPressed: onListPressed,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Daftar Soal'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (passage != null && passage.isNotEmpty) ...[
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.article_outlined, size: 18, color: AppColors.muted),
                    SizedBox(width: 8),
                    Text(
                      'BACAAN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  passage,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                question.text,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < question.options.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == question.options.length - 1 ? 0 : 10,
                  ),
                  child: OptionTile(
                    label: Question.labelOf(i),
                    text: question.options[i],
                    state: selectedIndex == i
                        ? OptionState.selected
                        : OptionState.idle,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Daftar nomor soal ─────────────────────────

class _QuestionGrid extends StatelessWidget {
  const _QuestionGrid({
    required this.count,
    required this.current,
    required this.isAnswered,
    required this.color,
    required this.onTap,
  });

  final int count;
  final int current;
  final bool Function(int index) isAnswered;
  final Color color;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < count; i++)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTap(i),
            child: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isAnswered(i) ? color : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: i == current ? AppColors.ink : AppColors.border,
                  width: i == current ? 2 : 1,
                ),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isAnswered(i) ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GridLegend extends StatelessWidget {
  const _GridLegend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color fill, Color border, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: border),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        dot(AppColors.primary, AppColors.primary, 'Sudah dijawab'),
        dot(AppColors.surface, AppColors.border, 'Belum dijawab'),
      ],
    );
  }
}

// ───────────────────────── Bar bawah ─────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.isFirst,
    required this.isLast,
    required this.color,
    required this.answered,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onSubmit,
  });

  final bool isFirst;
  final bool isLast;
  final Color color;
  final int answered;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final roomy = MediaQuery.sizeOf(context).width >= Breakpoints.compact;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPagePadding(context),
            vertical: 12,
          ),
          child: ContentWidth(
            maxWidth: 820,
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: isFirst ? null : onPrev,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: EdgeInsets.symmetric(horizontal: roomy ? 20 : 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 18),
                      if (roomy) ...[
                        const SizedBox(width: 8),
                        const Text('Sebelumnya'),
                      ],
                    ],
                  ),
                ),
                if (roomy) ...[
                  const SizedBox(width: 14),
                  Text(
                    '$answered/$total terjawab',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 140),
                      child: FilledButton(
                        onPressed: isLast ? onSubmit : onNext,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLast ? 'Kumpulkan' : 'Berikutnya',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLast ? Icons.send_rounded : Icons.arrow_forward,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Tanda air ─────────────────────────

/// Tulisan nama + NIS yang diulang miring di atas soal. Tidak menghalangi sentuhan.
class _Watermark extends StatelessWidget {
  const _Watermark({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.black.withAlpha(20),
    );
    return IgnorePointer(
      child: ClipRect(
        child: OverflowBox(
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Transform.rotate(
            angle: -0.45,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < 16; r++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < 9; c++)
                          Padding(
                            padding: EdgeInsets.only(
                              left: c == 0 ? (r.isEven ? 0 : 70) : 36,
                            ),
                            child: Text(
                              text,
                              maxLines: 1,
                              softWrap: false,
                              style: style,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
