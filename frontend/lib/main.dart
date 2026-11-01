import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/student_dashboard/presentation/providers/room_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load();
  } catch (_) {
    // Fallback baseUrl di DioClient tetap dipakai.
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      title: 'AdaNando UTBK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const LoginPage(),
      routes: {
        // Dipakai tombol logout di dashboard admin
        '/login': (_) => const LoginPage(),
      },
    );
  }
}
