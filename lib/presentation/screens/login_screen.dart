import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vinculo_empresa_screen.dart';
import 'espera_aprobacion_screen.dart';
import 'main_navigator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = _client.auth.onAuthStateChange.listen((data) async {
      final Session? session = data.session;
      if (session != null) {
        await _procesarFlujoUsuario(session.user);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _ejecutarAutenticacion(OAuthProvider provider) async {
    setState(() => _isLoading = true);
    try {
      final String urlRedirect = kIsWeb
          ? 'https://starlit-hummingbird-aa5e3c.netlify.app/'
          : 'io.supabase.autoncf://login-callback';

      await _client.auth.signInWithOAuth(
        provider,
        redirectTo: urlRedirect,
      );
    } catch (e) {
      _mostrarAlerta("Error al conectar: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _procesarFlujoUsuario(User user) async {
    try {
      final relacion = await _client
          .from('usuarios_empresas')
          .select('estado, rol')
          .eq('usuario_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (relacion == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => VinculoEmpresaScreen(usuarioId: user.id)),
              (route) => false,
        );
        return;
      }

      final String estado = (relacion['estado'] ?? 'pendiente').toString().trim().toLowerCase();
      final String rol = (relacion['rol'] ?? 'operador').toString().trim().toLowerCase();

      if (estado == 'aprobado' || estado == 'approved' || rol == 'admin') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator()),
              (route) => false,
        );
      } else if (estado == 'pendiente') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => EsperaAprobacionScreen(usuarioId: user.id)),
              (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => VinculoEmpresaScreen(usuarioId: user.id)),
              (route) => false,
        );
      }
    } catch (e) {
      print("Error en flujo de login: $e");
      setState(() => _isLoading = false);
    }
  }

  void _mostrarAlerta(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('AutoNCF'),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person, size: 70, color: Colors.blueGrey[800]),
              const SizedBox(height: 12),
              const Text('AutoNCF', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('Sistema de Auditoría Nativo', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              _isLoading
                  ? const CircularProgressIndicator()
                  : Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _ejecutarAutenticacion(OAuthProvider.google),
                    icon: const Icon(Icons.g_mobiledata, size: 30),
                    label: const Text('Continuar con Google'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _ejecutarAutenticacion(OAuthProvider.azure),
                    icon: const Icon(Icons.window, size: 24),
                    label: const Text('Continuar con Microsoft (Hotmail)'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}