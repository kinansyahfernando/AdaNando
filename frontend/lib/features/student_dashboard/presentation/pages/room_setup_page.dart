import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/bank_lookup.dart';
import '../../data/models/session_result.dart';
import '../providers/room_provider.dart';
import '../widgets/section_card.dart';
import 'room_lobby_page.dart';
import 'session_result_page.dart';
import 'timed_quiz_page.dart';

/// Form pengaturan sesi: pilih subtes, jumlah soal, dan durasi.
/// - solo = true  -> Try Out Mandiri (langsung mulai, tanpa server)
/// - solo = false -> Buat Room Belajar Bareng
class RoomSetupPage extends StatefulWidget {
  const RoomSetupPage({super.key, required this.solo});

  final bool solo;

  static Route<void> route({required bool solo}) {
    return MaterialPageRoute<void>(builder: (_) => RoomSetupPage(solo: solo));
  }

  @override
  State<RoomSetupPage> createState() => _RoomSetupPageState();
}

class _RoomSetupPageState extends State<RoomSetupPage> {
  static const List<int> _durationOptions = [5, 10, 15, 30, 45, 60];

  String _subtestId = mixSubtestId;
  int _count = 10;
  int _minutes = 10;
  bool _loading = false;

  int get _available => BankLookup.availableCount(_subtestId);

  /// Jumlah soal yang dipakai, dijaga agar tidak melebihi soal tersedia.
  int get _effectiveCount {
    final available = _available;
    if (available <= 0) return 0;
    return min(max(_count, 1), available);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final count = _effectiveCount;
    if (count == 0) {
      _showMessage('Belum ada soal untuk pilihan ini.');
      return;
    }
    if (widget.solo) {
      _startSolo(count);
    } else {
      await _createRoom(count);
    }
  }

  void _startSolo(int count) {
    final subtest = BankLookup.subtestById(_subtestId);
    final questions = BankLookup.pick(_subtestId, count);
    final endsAt = DateTime.now().add(Duration(minutes: _minutes));

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TimedQuizPage(
          title: 'Try Out Mandiri',
          subtest: subtest,
          questions: questions,
          remainingSeconds: () {
            final ms = endsAt.difference(DateTime.now()).inMilliseconds;
            return ms <= 0 ? 0 : (ms / 1000).ceil();
          },
          onFinish: (answers) async {
            final result = SessionResult(
              subtest: subtest,
              questions: questions,
              answers: answers,
            );
            return MaterialPageRoute<void>(
              builder: (_) => SessionResultPage(result: result),
            );
          },
        ),
      ),
    );
  }

  Future<void> _createRoom(int count) async {
    final provider = context.read<RoomProvider>();
    final questions = BankLookup.pick(_subtestId, count);

    setState(() => _loading = true);
    final ok = await provider.createRoom(
      subtestId: _subtestId,
      questionIds: questions.map((q) => q.id).toList(),
      durationSeconds: _minutes * 60,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacement(RoomLobbyPage.route());
    } else {
      setState(() => _loading = false);
      _showMessage(provider.error ?? 'Gagal membuat room.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);
    final subtest = BankLookup.subtestById(_subtestId);
    final available = _available;
    final count = _effectiveCount;
    final color = subtest.color;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.solo ? 'Try Out Mandiri' : 'Buat Room',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          child: ContentWidth(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.solo
                      ? 'Atur try out untuk mengasah kemampuanmu sendiri.'
                      : 'Atur soal dan waktu. Semua peserta room mengerjakan soal yang sama.',
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Subtes'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in BankLookup.choices)
                            ChoiceChip(
                              label: Text(
                                s.id == mixSubtestId ? 'Campuran' : s.code,
                              ),
                              selected: s.id == _subtestId,
                              selectedColor: s.color.withAlpha(40),
                              onSelected: (_) =>
                                  setState(() => _subtestId = s.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtest.name,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtest.description,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: _Label('Jumlah soal')),
                          Text(
                            available == 0 ? '-' : '$count soal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      if (available >= 2)
                        Slider(
                          min: 1,
                          max: available.toDouble(),
                          divisions: available - 1,
                          value: count.toDouble(),
                          label: '$count',
                          activeColor: color,
                          onChanged: (v) => setState(() => _count = v.round()),
                        )
                      else
                        const SizedBox(height: 6),
                      Text(
                        available == 0
                            ? 'Belum ada soal untuk pilihan ini.'
                            : 'Tersedia $available soal untuk pilihan ini.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Durasi'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final m in _durationOptions)
                            ChoiceChip(
                              label: Text('$m menit'),
                              selected: m == _minutes,
                              selectedColor: color.withAlpha(40),
                              onSelected: (_) => setState(() => _minutes = m),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Saran: sekitar 1–2 menit per soal.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: (_loading || count == 0) ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(widget.solo ? Icons.play_arrow_rounded : Icons.add),
                  label: Text(
                    widget.solo ? 'Mulai Try Out' : 'Buat Room',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    );
  }
}
