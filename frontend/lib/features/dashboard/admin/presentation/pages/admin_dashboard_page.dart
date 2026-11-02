import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/network/dio_client.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

/// Guru & admin mengelola semuanya lewat Panel Web: siswa, bank soal, ujian,
/// pantau ujian langsung, potensi siswa, dan hasil.
/// Setelah login, halaman ini langsung membuka panel (sudah masuk, tanpa login ulang).
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  /// Alamat panel = alamat server API dengan akhiran /admin.
  /// (Saat development: server backend di port 3000, BUKAN port Flutter.)
  String get _panelUrl =>
      DioClient.baseUrl.replaceFirst(RegExp(r'/api/v1/?$'), '/admin/');

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.autoOpenPanel) {
      auth.autoOpenPanel = false; // hanya sekali setelah login
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(sso: true));
    }
  }

  Future<void> _open({bool sso = true}) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = DioClient.token;
    // Token dibawa lewat bagian #fragment (tidak dikirim ke server, dihapus panel segera)
    final url = (sso && token != null && token.isNotEmpty)
        ? '$_panelUrl#sso=$token'
        : _panelUrl;

    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        // Web: buka di tab yang sama agar tidak diblokir pop-up blocker
        webOnlyWindowName: kIsWeb ? '_self' : null,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Tidak bisa membuka. Buka manual: $_panelUrl')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final roleLabel = auth.userRole == 'admin' ? 'Admin' : 'Guru';

    return Scaffold(
      appBar: AppBar(
        title: const Text('AdaNando'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Halo, ${auth.userName ?? ''} ($roleLabel)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Membuka Panel Admin… Bila tidak terbuka otomatis, tekan tombol di bawah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _open(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Buka Panel Admin'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SelectableText(
                    _panelUrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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