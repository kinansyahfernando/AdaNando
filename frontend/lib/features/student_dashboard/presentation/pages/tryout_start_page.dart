import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/secure_screen.dart';
import '../../data/bank_lookup.dart';
import '../../data/models/tryout.dart';
import '../../data/room_repository.dart' show ApiException;
import '../../data/tryout_session.dart';
import '../widgets/section_card.dart';
import 'tryout_section_page.dart';

/// Pintu masuk Try Out Mandiri: 160 soal, 195 menit, 7 subtes berurutan.
class TryoutStartPage extends StatefulWidget {
  const TryoutStartPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const TryoutStartPage());
  }

  @override
  State<TryoutStartPage> createState() => _TryoutStartPageState();
}

class _TryoutStartPageState extends State<TryoutStartPage> {
  bool _loading = false;

  String _readable(Object e) {
    if (e is ApiException) return e.message;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return 'Tidak bisa terhubung ke server. Pastikan internet aktif dan backend menyala.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _start() async {
    setState(() => _loading = true);

    final session = TryoutSession();
    try {
      await session.begin();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_readable(e))));
      return;
    }

    await SecureScreen.enable();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(TryoutSectionPage.routeFor(session));
  }

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Try Out Mandiri',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
                const _Hero(),
                const SizedBox(height: 14),
                SectionCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < TryoutPlan.items.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.border),
                        _PlanRow(item: TryoutPlan.items[i], number: i + 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionCard(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Rule(
                        icon: Icons.lock_clock_outlined,
                        text:
                            'Subtes berurutan dan tidak bisa kembali. Waktu dihitung server.',
                      ),
                      SizedBox(height: 10),
                      _Rule(
                        icon: Icons.phonelink_erase_outlined,
                        text:
                            'Keluar aplikasi atau pindah tab otomatis mengumpulkan dan mengakhiri try out.',
                      ),
                      SizedBox(height: 10),
                      _Rule(
                        icon: Icons.screenshot_outlined,
                        text:
                            'Screenshot dan rekam layar diblokir (di aplikasi Android).',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _loading ? null : _start,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 26),
                  label: const Text(
                    'Start',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 56),
                    backgroundColor: AppColors.penalaran,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Try Out UTBK',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Simulasi lengkap seperti ujian sebenarnya.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroChip('${TryoutPlan.totalQuestions} soal'),
              _HeroChip('${TryoutPlan.totalMinutes} menit'),
              _HeroChip('7 subtes'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.item, required this.number});

  final TryoutPlanItem item;
  final int number;

  @override
  Widget build(BuildContext context) {
    final color = BankLookup.allSubtests
        .firstWhere(
          (s) => s.code == item.code,
          orElse: () => mixSubtest,
        )
        .color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.code,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.questions} soal',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                '${item.minutes} menit',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
