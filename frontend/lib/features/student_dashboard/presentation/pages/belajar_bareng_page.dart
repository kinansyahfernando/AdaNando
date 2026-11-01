import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/room_provider.dart';
import 'room_lobby_page.dart';
import 'room_setup_page.dart';
import 'tryout_start_page.dart';

/// Pusat fitur Belajar Bareng: buat room, gabung room, atau try out mandiri.
class BelajarBarengPage extends StatelessWidget {
  const BelajarBarengPage({super.key});

  Future<void> _joinRoom(BuildContext context) async {
    final joined = await showDialog<bool>(
      context: context,
      builder: (_) => const _JoinRoomDialog(),
    );
    if (joined == true && context.mounted) {
      Navigator.of(context).push(RoomLobbyPage.route());
    }
  }

  @override
  Widget build(BuildContext context) {
    final hPad = horizontalPagePadding(context);

    final createCard = _ActionCard(
      icon: Icons.add_circle_outline,
      color: AppColors.bareng,
      title: 'Buat Room',
      text: 'Buat ruang belajar lalu bagikan kodenya ke teman-temanmu.',
      onTap: () => Navigator.of(context).push(RoomSetupPage.route(solo: false)),
    );
    final joinCard = _ActionCard(
      icon: Icons.login,
      color: AppColors.primary,
      title: 'Gabung Room',
      text: 'Punya kode dari teman? Masukkan kodenya untuk bergabung.',
      onTap: () => _joinRoom(context),
    );
    final soloCard = _ActionCard(
      icon: Icons.person_outline,
      color: AppColors.penalaran,
      title: 'Try Out Mandiri',
      text: 'Simulasi UTBK lengkap: 160 soal, 195 menit, 7 subtes berurutan.',
      onTap: () => Navigator.of(context).push(TryoutStartPage.route()),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 24),
        child: ContentWidth(
          maxWidth: 1000,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Belajar Bareng',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kerjakan soal bersama teman dalam waktu yang sama, lalu lihat skor dan peringkat di HP masing-masing.',
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 720) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: createCard),
                          const SizedBox(width: 12),
                          Expanded(child: joinCard),
                          const SizedBox(width: 12),
                          Expanded(child: soloCard),
                        ],
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      createCard,
                      const SizedBox(height: 12),
                      joinCard,
                      const SizedBox(height: 12),
                      soloCard,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Dialog gabung room ─────────────────────────

class _JoinRoomDialog extends StatefulWidget {
  const _JoinRoomDialog();

  @override
  State<_JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<_JoinRoomDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = 'Masukkan kode room dari temanmu.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = context.read<RoomProvider>();
    final ok = await provider.joinRoom(code);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _error = provider.error ?? 'Gagal bergabung ke room.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gabung Room'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Masukkan kode room yang kamu terima.',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_loading,
            maxLength: 6,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            ],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              hintText: 'KODE',
              counterText: '',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _join(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _join,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Gabung'),
        ),
      ],
    );
  }
}
