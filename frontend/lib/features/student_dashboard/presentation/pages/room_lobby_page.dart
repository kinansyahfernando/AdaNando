import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/bank_lookup.dart';
import '../../data/models/room.dart';
import '../providers/room_provider.dart';
import '../widgets/section_card.dart';
import 'room_quiz_page.dart';

/// Ruang tunggu: peserta berkumpul, host menekan Mulai.
/// Saat host memulai, semua HP otomatis pindah ke halaman ujian.
class RoomLobbyPage extends StatefulWidget {
  const RoomLobbyPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const RoomLobbyPage());
  }

  @override
  State<RoomLobbyPage> createState() => _RoomLobbyPageState();
}

class _RoomLobbyPageState extends State<RoomLobbyPage> {
  late final RoomProvider _provider;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<RoomProvider>();
    _provider.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChange());
  }

  @override
  void dispose() {
    _provider.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted || _navigated) return;
    final room = _provider.room;
    if (room == null) return;

    if (room.isRunning) {
      _navigated = true;
      Navigator.of(context).pushReplacement(RoomQuizPage.route());
    } else if (room.isClosed || room.isFinished) {
      _navigated = true;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      _provider.reset();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Room sudah ditutup.')),
      );
    }
  }

  Future<void> _start() async {
    final ok = await _provider.startRoom();
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_provider.error ?? 'Gagal memulai room.')),
    );
  }

  Future<void> _confirmLeave() async {
    final isHost = _provider.room?.iAmHost ?? false;

    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar dari room?'),
        content: Text(
          isHost
              ? 'Kamu host. Room akan ditutup untuk semua peserta.'
              : 'Kamu bisa bergabung lagi selama room belum dimulai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (leave != true || !mounted) return;
    _navigated = true;
    final navigator = Navigator.of(context);
    await _provider.leave();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoomProvider>();
    final room = provider.room;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Keluar dari room',
            onPressed: _confirmLeave,
          ),
          title: const Text(
            'Ruang Tunggu',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        body: room == null
            ? const Center(child: CircularProgressIndicator())
            : _LobbyBody(room: room, provider: provider, onStart: _start),
      ),
    );
  }
}

class _LobbyBody extends StatelessWidget {
  const _LobbyBody({
    required this.room,
    required this.provider,
    required this.onStart,
  });

  final RoomState room;
  final RoomProvider provider;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CodeCard(room: room),
        const SizedBox(height: 14),
        _InfoCard(room: room),
        const SizedBox(height: 14),
        _ActionArea(room: room, provider: provider, onStart: onStart),
      ],
    );
    final right = _PlayersCard(room: room);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
        child: ContentWidth(
          maxWidth: 1000,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (provider.connectionProblem) ...[
                const _Notice(
                  text: 'Koneksi bermasalah, mencoba menyambung kembali…',
                ),
                const SizedBox(height: 12),
              ],
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 400, child: left),
                    const SizedBox(width: 20),
                    Expanded(child: right),
                  ],
                )
              else ...[
                left,
                const SizedBox(height: 14),
                right,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      color: AppColors.bareng.withAlpha(18),
      borderColor: AppColors.bareng.withAlpha(80),
      child: Column(
        children: [
          const Text(
            'KODE ROOM',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: AppColors.bareng,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              room.code,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bagikan kode ini ke teman-temanmu.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: room.code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Kode room disalin')),
                );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Salin kode'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context) {
    final subtest = BankLookup.subtestById(room.subtestId);
    final minutes = (room.durationSeconds / 60).round();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtest.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: subtest.color,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.quiz_outlined,
                label: '${room.questionCount} soal',
              ),
              _InfoChip(icon: Icons.timer_outlined, label: '$minutes menit'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.room,
    required this.provider,
    required this.onStart,
  });

  final RoomState room;
  final RoomProvider provider;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    if (room.iAmHost) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: provider.busy ? null : onStart,
            icon: provider.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'Mulai Sekarang',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: AppColors.bareng,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pastikan semua teman sudah masuk. Setelah dimulai, peserta baru tidak bisa bergabung.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted),
          ),
        ],
      );
    }

    return SectionCard(
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Menunggu host memulai ujian…',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayersCard extends StatelessWidget {
  const _PlayersCard({required this.room});

  final RoomState room;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Peserta (${room.players.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          for (final p in room.players)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: p.isHost
                        ? AppColors.bareng
                        : AppColors.primary.withAlpha(30),
                    child: Text(
                      p.name.trim().isEmpty
                          ? '?'
                          : p.name.trim().substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: p.isHost ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (p.isHost) const _Tag('Host', AppColors.bareng),
                  if (p.isMe) ...[
                    const SizedBox(width: 6),
                    const _Tag('Kamu', AppColors.primary),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
