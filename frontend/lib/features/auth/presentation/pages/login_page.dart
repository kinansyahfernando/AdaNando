import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_page.dart';
import '../../../student_dashboard/presentation/pages/student_dashboard_page.dart';
import '../../../dashboard/admin/presentation/pages/admin_dashboard_page.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    final success = await provider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Berhasil!'), backgroundColor: Colors.green),
      );

      // --- LOGIKA ROUTING MENGGUNAKAN ROLE ASLI DARI BACKEND ---
      final role = provider.userRole; 
      
      if (role == "admin") {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          (Route<dynamic> route) => false, // Hapus riwayat halaman
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
          (Route<dynamic> route) => false, // Hapus riwayat halaman
        );
      }
      // ---------------------------------------------------------
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'Login Gagal'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.school, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                'AdaNando',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              authProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('MASUK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                },
                child: const Text('Belum punya akun? Daftar di sini'),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
