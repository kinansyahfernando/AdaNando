import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Ganti password. [forced] = true saat akun baru / habis direset admin:
/// siswa tidak bisa memakai fitur lain sebelum selesai.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.forced = false});

  final bool forced;

  static Route<void> route() => MaterialPageRoute<void>(
    builder: (_) => const ChangePasswordPage(),
  );

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_new.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password tidak sama.');
      return;
    }
    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final ok = await auth.changePassword(_old.text, _new.text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = auth.errorMessage);
      return;
    }
    if (!widget.forced) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diganti.')),
      );
    }
    // Bila forced: AuthGate otomatis pindah ke beranda karena mustChangePassword = false.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.forced,
          title: Text(widget.forced ? 'Buat Password Baru' : 'Ganti Password'),
          actions: [
            if (widget.forced)
              TextButton(
                onPressed: () => context.read<AuthProvider>().logout(),
                child: const Text('Keluar'),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.forced)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Demi keamanan akunmu, ganti password sementara dari sekolah dengan password baru yang hanya kamu yang tahu.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    TextField(
                      controller: _old,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: widget.forced
                            ? 'Password sementara'
                            : 'Password lama',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _new,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password baru',
                        helperText: 'Minimal 8 karakter, ada huruf dan angka',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirm,
                      obscureText: true,
                      onSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'Ulangi password baru',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 20),
                    auth.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 50),
                            ),
                            child: const Text('Simpan Password'),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
