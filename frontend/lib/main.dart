import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'core/app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/change_password_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/dashboard/admin/presentation/pages/admin_dashboard_page.dart';
import 'features/student_dashboard/presentation/pages/student_dashboard_page.dart';
import 'features/student_dashboard/presentation/providers/room_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (_) {
    // Tanpa .env, DioClient memakai alamat bawaan sesuai platform.
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        // State room Belajar Bareng (dipakai lobby, ujian, dan hasil)
        ChangeNotifierProvider(create: (_) => RoomProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdaNando',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}

/// Menentukan layar utama dari status login: splash → login → ganti password
/// (akun baru) → beranda sesuai role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isLoggedIn) return const LoginPage();
    if (auth.mustChangePassword) {
      return const ChangePasswordPage(forced: true);
    }
    if (auth.userRole == 'siswa') return const StudentDashboardPage();
    return const AdminDashboardPage();
  }
}
