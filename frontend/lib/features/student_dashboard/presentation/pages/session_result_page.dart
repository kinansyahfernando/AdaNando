import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/models/room.dart';
import '../../data/models/session_result.dart';
import '../providers/room_provider.dart';
import '../widgets/answer_review_list.dart';
import '../widgets/section_card.dart';

/// Hasil try out. Jika [roomCode] terisi (Belajar Bareng), halaman ini juga
/// menampilkan skor dan peringkat semua peserta setelah semua selesai.
class SessionResultPage extends StatefulWidget {
  const SessionResultPage({super.key, required this.result, this.roomCode});

  final SessionResult result;
  final String? roomCode;

  @override
  State<SessionResultPage> createState() => _SessionResultPageState();
}

class _SessionResultPageState extends State<SessionResultPage> {
  bool get _isRoom => widget.roomCode != null;

  @override
  void initState() {
    super.initState();
    if (_isRoom) {
      final provider = context.read<RoomProvider>();
      provider.startPolling();
      provider.refresh();
    }
  }

  void _finish() {
    if (_isRoom) context.read<RoomProvider>().reset();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String get _message {
    final pct = widget.result.accuracy * 100;
    if (pct >= 80) return 'Luar biasa! Pertahankan ya.';
    if (pct >= 60) return 'Bagus! Sedikit lagi untuk hasil maksimal.';
    return 'Tetap semangat! Pelajari pembahasannya lalu coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    final result = widget.result;

    final summary = _SummaryCard(result: result, message: _message);
    final doneButton = FilledButton.icon(
      onPressed: _finish,
      icon: const Icon(Icons.home_rounded),
      label: const Text('Selesai'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: result.subtest.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    Widget? ranking;
    if (_isRoom) {
      final provider = context.watch<RoomProvider>();
      ranking = _RankingSection(room: provider.room, provider: provider);
    }

    final review = AnswerReviewList(result: result);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            _isRoom ? 'Hasil Belajar Bareng' : 'Hasil Try Out',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
            child: ContentWidth(
              maxWidth: 1000,
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 340,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              summary,
                              const SizedBox(height: 16),
                              doneButton,
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (ranking != null) ...[
                                ranking,
                                const SizedBox(height: 24),
                              ],
                              review,
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        summary,
                        const SizedBox(height: 16),
                        if (ranking != null) ...[
                          ranking,
                          const SizedBox(height: 16),
                        ],
                        doneButton,
                        const SizedBox(height: 24),
                        review,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Ringkasan skor ─────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result, required this.message});

  final SessionResult result;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = result.subtest.color;
    final percent = (result.accuracy * 100).round();

    return SectionCard(
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            result.subtest.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: result.accuracy,
                    strokeWidth: 10,
                    backgroundColor: AppColors.border,
                    color: color,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const Text(
                      'akurasi',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Benar',
                  value: '${result.correct}',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Salah',
                  value: '${result.wrong}',
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Kosong',
                  value: '${result.blank}',
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatTile(
            label: 'Poin',
            value: '${result.points}',
            color: AppColors.primary,
          ),
          const SizedBox(height: 10),
          const Text(
            'Poin: benar +4, salah −1, kosong 0',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Peringkat room ─────────────────────────

class _RankingSection extends StatelessWidget {
  const _RankingSection({required this.room, required this.provider});

  final RoomState? room;
  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    final current = room;

    Widget body;
    if (current == null || current.isClosed) {
      body = const Text(
        'Peringkat tidak tersedia.',
        style: TextStyle(fontSize: 14, color: AppColors.muted),
      );
    } else if (!current.isFinished) {
      final done = current.submittedCount;
      final total = current.players.length;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Menunggu teman lain selesai… ($done/$total sudah mengumpulkan)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          if (provider.connectionProblem) ...[
            const SizedBox(height: 10),
            const Text(
              'Koneksi bermasalah, mencoba menyambung kembali…',
              style: TextStyle(fontSize: 12.5, color: AppColors.danger),
            ),
          ],
        ],
      );
    } else {
      final me = current.me;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (me?.rank != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Peringkatmu: #${me!.rank} dari ${current.players.length}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.bareng,
                ),
              ),
            ),
          for (final p in current.players) _RankTile(player: p),
        ],
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: AppColors.bareng),
              SizedBox(width: 8),
              Text(
                'Peringkat',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.player});

  final RoomPlayer player;

  static const List<String> _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final rank = player.rank ?? 0;
    final medal = (rank >= 1 && rank <= 3) ? _medals[rank - 1] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: player.isMe ? AppColors.primary.withAlpha(20) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: player.isMe ? AppColors.primary : AppColors.border,
          width: player.isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 22))
                : Text(
                    '#$rank',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.isMe ? '${player.name} (Kamu)' : player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  player.submitted
                      ? '${player.correct ?? 0} benar · ${player.wrong ?? 0} salah'
                      : 'Tidak mengumpulkan',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${player.score ?? 0}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'poin',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
