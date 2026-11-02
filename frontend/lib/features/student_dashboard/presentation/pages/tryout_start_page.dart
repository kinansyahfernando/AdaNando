import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/security/exam_guard.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/secure_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/tryout.dart';
import '../../data/room_repository.dart' show ApiException;
import '../../data/tryout_repository.dart';
import '../../data/tryout_session.dart';
import '../widgets/section_card.dart';
import 'tryout_result_page.dart';
import 'tryout_section_page.dart';

/// Daftar ujian siswa: ujian dari guru (terjadwal, pakai token) dan
/// Try Out Mandiri UTBK yang bisa dikerjakan kapan saja.
class TryoutStartPage extends StatefulWidget {
  const TryoutStartPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const TryoutStartPage());
  }

  @override
  State<TryoutStartPage> createState() => _TryoutStartPageState();
}

class _TryoutStartPageState extends State<TryoutStartPage> {
  final _repo = TryoutRepository();
  List<ExamSummary>? _exams;
  String? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _readable(Object e) {
    if (e is ApiException) return e.message;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Tidak bisa terhubung ke server. Periksa koneksi internet / Wi-Fi sekolah.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _load() async {
    try {
      final list = await _repo.listExams();
      if (!mounted) return;
      setState(() {
        _exams = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _readable(e));
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askToken() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Token Ujian'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Masukkan token dari pengawas',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmRules(ExamSummary exam) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(exam.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Rule(
                icon: Icons.lock_clock_outlined,
                text:
                    'Bagian dikerjakan berurutan dan tidak bisa kembali. Waktu dihitung server.',
              ),
              const SizedBox(height: 10),
              _Rule(
                icon: Icons.phonelink_erase_outlined,
                text: exam.maxViolations > 0
                    ? 'Jangan pindah tab / aplikasi atau keluar layar penuh. '
                          'Kamu hanya punya ${exam.maxViolations} kali kesempatan; '
                          'pelanggaran ke-${exam.maxViolations} langsung mengakhiri dan mengumpulkan ujian.'
                    : 'Jangan pindah tab / aplikasi atau keluar layar penuh. Pelanggaran dicatat dan bisa dilihat guru / pengawas.',
              ),
              const SizedBox(height: 10),
              const _Rule(
                icon: Icons.verified_user_outlined,
                text:
                    'Jawabanmu tersimpan otomatis ke server. Nama dan NIS tampil sebagai tanda air.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mulai Ujian'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _start(ExamSummary exam) async {
    if (_busyId != null) return;

    final resuming = exam.isRunning;
    String? token;
    if (!resuming) {
      if (exam.requiresToken) {
        token = await _askToken();
        if (token == null || token.isEmpty || !mounted) return;
      }
      if (!await _confirmRules(exam) || !mounted) return;
    }

    // Layar penuh hanya boleh diminta tepat setelah tap pengguna.
    ExamGuard.requestFullscreen();
    setState(() => _busyId = exam.id);

    final session = TryoutSession();
    try {
      if (resuming) {
        await session.resume(exam.runningAttemptId!);
      } else {
        await session.begin(exam.id, token: token);
      }
    } catch (e) {
      ExamGuard.exitFullscreen();
      if (!mounted) return;
      setState(() => _busyId = null);
      _toast(_readable(e));
      return;
    }

    await SecureScreen.enable();
    if (!mounted) return;
    setState(() => _busyId = null);
    await Navigator.of(context).push(TryoutSectionPage.routeFor(session));
    if (mounted) _load();
  }

  Future<void> _openResult(ExamSummary exam) async {
    final id = exam.lastAttemptId;
    if (id == null) return;
    setState(() => _busyId = exam.id);
    final session = TryoutSession();
    try {
      await session.resume(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      _toast(_readable(e));
      return;
    }
    if (!mounted) return;
    setState(() => _busyId = null);
    await Navigator.of(context).push(TryoutResultPage.route(session));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);
    final auth = context.watch<AuthProvider>();

    Widget body;
    if (_error != null && _exams == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    } else if (_exams == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_exams!.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada ujian untuk kelasmu. Hubungi gurumu bila seharusnya ada.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          children: [
            ContentWidth(
              maxWidth: 680,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Halo, ${auth.userName ?? ''}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih ujian yang akan dikerjakan. Tarik layar ke bawah untuk memuat ulang.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  for (final exam in _exams!) ...[
                    _ExamCard(
                      exam: exam,
                      busy: _busyId == exam.id,
                      onStart: () => _start(exam),
                      onResult: () => _openResult(exam),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ujian & Try Out',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: body),
    );
  }
}

String _fmtDate(int? ms) {
  if (ms == null) return '-';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
    required this.busy,
    required this.onStart,
    required this.onResult,
  });

  final ExamSummary exam;
  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onResult;

  @override
  Widget build(BuildContext context) {
    final color = exam.isTryout ? AppColors.penalaran : AppColors.primary;
    final minutes = (exam.totalSeconds / 60).round();

    String? statusText;
    Color statusColor = AppColors.muted;
    if (exam.isRunning) {
      statusText = 'Sedang berjalan';
      statusColor = AppColors.success;
    } else if (exam.phase == 'upcoming') {
      statusText = 'Dimulai ${_fmtDate(exam.startAt)}';
      statusColor = AppColors.penalaran;
    } else if (exam.phase == 'ended') {
      statusText = 'Sudah berakhir';
    } else if (exam.lastStatus == 'finished') {
      statusText = 'Sudah dikerjakan';
      statusColor = AppColors.success;
    }

    final hasResult = exam.lastAttemptId != null && !exam.isRunning;

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                exam.isTryout ? Icons.emoji_events_outlined : Icons.assignment_outlined,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exam.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if ((exam.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              exam.description!,
              style: const TextStyle(color: AppColors.muted, fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip('${exam.totalQuestions} soal'),
              _Chip('$minutes menit'),
              _Chip('${exam.sections} bagian'),
              if (exam.requiresToken) const _Chip('Pakai token'),
              if (exam.endAt != null) _Chip('Tutup ${_fmtDate(exam.endAt)}'),
            ],
          ),
          if (statusText != null) ...[
            const SizedBox(height: 8),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (exam.isRunning || exam.canStart)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onStart,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            exam.isRunning
                                ? Icons.play_circle_outline
                                : Icons.play_arrow_rounded,
                          ),
                    label: Text(exam.isRunning ? 'Lanjutkan' : 'Mulai'),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
              if (hasResult) ...[
                if (exam.isRunning || exam.canStart) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onResult,
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: const Text('Lihat Hasil'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.penalaran),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
      ],
    );
  }
}
