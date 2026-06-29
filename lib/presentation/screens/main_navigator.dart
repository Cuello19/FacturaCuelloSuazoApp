import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_service.dart';
import 'historial_facturas_screen.dart';
import 'camera_scan_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'vinculo_empresa_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  StreamSubscription? _securitySubscription;

  String _estatusAcceso = 'pendiente';
  bool _checkingSecurity = true;

  @override
  void initState() {
    super.initState();
    _inicializarEscuchaSeguridad();
  }

  @override
  void dispose() {
    _securitySubscription?.cancel();
    super.dispose();
  }

  void _inicializarEscuchaSeguridad() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _expulsarUsuario();
      return;
    }

    final estatusInicial = await _authService.verificarEstatusSolicitud(user.id);

    if (estatusInicial == 'sin_empresa') {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => VinculoEmpresaScreen(usuarioId: user.id)),
            (route) => false,
      );
      return;
    }

    if (estatusInicial == 'rechazado') {
      _expulsarUsuario();
      return;
    }

    if (mounted) {
      setState(() {
        _estatusAcceso = estatusInicial;
        _checkingSecurity = false;
      });
    }

    _securitySubscription = _authService.escucharEstatusAcceso(user.id).listen((snapshot) {
      if (snapshot.isEmpty) {
        _securitySubscription?.cancel();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => VinculoEmpresaScreen(usuarioId: user.id)),
                (route) => false,
          );
        }
        return;
      }

      final relacionActual = snapshot.first;
      final nuevoEstado = relacionActual['estado'];
      final rol = relacionActual['rol'];

      if (rol == 'admin' || nuevoEstado == 'approved' || nuevoEstado == 'aprobado') {
        if (mounted) {
          setState(() {
            _estatusAcceso = 'aprobado';
          });
        }
        return;
      }

      if (nuevoEstado == 'rechazado') {
        _securitySubscription?.cancel();
        _mostrarAlertaDeExpulsion();
        return;
      }
    });
  }

  void _expulsarUsuario() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _mostrarAlertaDeExpulsion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Acceso Denegado', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Tu solicitud de acceso ha sido rechazada o tu cuenta corporativa fue revocada.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _expulsarUsuario();
            },
            child: const Text('Entendido', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSecurity) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_estatusAcceso == 'pendiente') {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.amber)),
                const SizedBox(height: 24),
                const Text('Esperando Validación...', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'Tu solicitud de vinculación está en revisión.\n\nTan pronto seas autorizado, esta pantalla se desbloqueará de forma automática.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 40),
                TextButton.icon(
                  onPressed: () async {
                    await _authService.cerrarSesion();
                    _expulsarUsuario();
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.red),
                  label: const Text('Cancelar y volver al Login', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                )
              ],
            ),
          ),
        ),
      );
    }

    // 🚀 Lista corregida removiendo constructores constantes inválidos
    final List<Widget> screens = [
      const HistorialFacturasScreen(),
      const CameraScreen(),
      const PerfilScreen(), // Apunta directo al PerfilScreen dinámico de tu app
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.grey[100],
        selectedItemColor: const Color(0xFF01579B),
        unselectedItemColor: Colors.blueGrey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt_outlined),
            activeIcon: Icon(Icons.camera_alt),
            label: 'Cámara',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}