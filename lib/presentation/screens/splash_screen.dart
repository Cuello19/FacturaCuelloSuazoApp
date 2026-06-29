import 'package:flutter/material.dart';
import 'main_navigator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Espera 3 segundos y salta al MainNavigator
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Muestra tu logo centrado de forma estética
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'web/favicon.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Si no encuentra el asset físico por ahora, pone un fallback chulo
                  return const Icon(Icons.receipt_long, size: 80, color: Color(0xFF01579B));
                },
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "AutoNCF",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
            ),
            const SizedBox(height: 8),
            const Text("Bilexis Auditoría Fiscal", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            const CircularProgressIndicator(strokeWidth: 3),
          ],
        ),
      ),
    );
  }
}