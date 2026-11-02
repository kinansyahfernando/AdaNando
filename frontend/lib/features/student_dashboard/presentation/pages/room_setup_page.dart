import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/bank_lookup.dart';
import '../providers/room_provider.dart';
import '../widgets/section_card.dart';
import 'room_lobby_page.dart';

/// Susunan UTBK yang ditampilkan saat pilihan "UTBK" dipilih.
/// Harus sama dengan backend/src/modules/tryout/tryout.config.js.
const List<({String code, String name, int questions, int seconds})>
_utbkSections = [
  (code: 'PU', name: 'Penalaran Umum', questions: 30, seconds: 30 * 60),
  (
    code: 'PPU',
    name: 'Pengetahuan dan Pemahaman Umum',
    questions: 20,
    seconds: 15 * 60,
  ),
  (
    code: 'PBM',
    name: 'Pemahaman Bacaan dan Menulis',
    questions: 20,
    seconds: 25 * 60,
  ),
  (code: 'PK', name: 'Pengetahuan Kuantitatif', questions: 20, seconds: 20 * 60),
  (code: 'LBI', name: 'Literasi Bahasa Indonesia', questions: 30, seconds: 2550),
  (code: 'LBE', name: 'Literasi Bahasa Inggris', questions: 20, seconds: 20 * 60),
  (code: 'PM', name: 'Penalaran Matematika', questions: 20, seconds: 2550),
];

/// Form pengaturan sesi: pilih subtes, jumlah soal, dan durasi.
/// - solo = true  -> Try Out Mandiri (langsung mulai, tanpa server)
/// - solo = false -> Buat Room Belajar Bareng
///
/// Bila "UTBK" dipilih, jumlah soal dan waktu DIKUNCI (160 soal, 195 menit)
/// sama seperti UTBK, jadi tidak bisa diatur.
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

  String _subtestId = utbkSubtestId;
  int _count = 10;
  int _minutes = 10;
  bool _loading = false;

  bool get _isUtbk => _subtestId == utbkSubtestId;

  /// Batas atas jumlah soal per sesi (soal sebenarnya dipilih server).
  int get _available => _isUtbk ? utbkTotalQuestions : 30;

  /// Jumlah soal yang dipakai, dijaga agar tidak melebihi soal tersedia.
  /// Mode UTBK selalu 160.
  int get _effectiveCount {
    if (_isUtbk) return utbkTotalQuestions;
    final available = _available;
    if (available <= 0) return 0;
    return min(max(_count, 1), available);
  }

  /// Durasi (detik). Mode UTBK selalu 195 menit.
  int get _effectiveSeconds => _isUtbk ? utbkTotalSeconds : _minutes * 60;

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
    await _createRoom(count);
  }

  Future<void> _createRoom(int count) async {
    final provider = context.read<RoomProvider>();

    setState(() => _loading = true);
    final ok = await provider.createRoom(
      subtestId: _subtestId,
      count: count,
      durationSeconds: _effectiveSeconds,
    );
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacement(RoomLobbyPage.route());
    } else {
      setState(() => _loading = false);
      _showMessage(provider.error ?? 'Gagal membuat room.');
    }
  }

  static String _minutesText(int seconds) {
    final m = seconds / 60;
    return m == m.roundToDouble()
        ? '${m.round()} mnt'
        : '${m.toStringAsFixed(1).replaceAll('.', ',')} mnt';
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
                              label: Text(s.code),
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
                if (_isUtbk)
                  _UtbkInfoCard(color: color, minutesText: _minutesText)
                else ...[
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
                            onChanged: (v) =>
                                setState(() => _count = v.round()),
                          )
                        else
                          const SizedBox(height: 6),
                        Text(
                          available == 0
                              ? 'Belum ada soal untuk pilihan ini.'
                              : 'Maksimal $available soal per sesi. Bila bank soal lebih sedikit, jumlahnya menyesuaikan.',
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
                                onSelected: (_) =>
                                    setState(() => _minutes = m),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Saran: sekitar 1–2 menit per soal.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

/// Pengganti kartu "Jumlah soal" + "Durasi" saat UTBK dipilih: nilainya terkunci.
class _UtbkInfoCard extends StatelessWidget {
  const _UtbkInfoCard({required this.color, required this.minutesText});

  final Color color;
  final String Function(int seconds) minutesText;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              const Expanded(child: _Label('Soal & waktu sesuai UTBK')),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Jumlah soal dan waktu sudah ditetapkan dan tidak bisa diubah.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '$utbkTotalQuestions',
                  label: 'soal',
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  value: '${utbkTotalSeconds ~/ 60}',
                  label: 'menit',
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          for (final s in _utbkSections)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      s.code,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${s.questions} soal · ${minutesText(s.seconds)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Soal dikerjakan berurutan per subtes dalam satu waktu bersama. '
            'Bila bank soal lebih sedikit dari 160, jumlahnya menyesuaikan.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
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
