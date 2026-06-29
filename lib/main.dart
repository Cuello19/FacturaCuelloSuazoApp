import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'presentation/screens/main_navigator.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/vinculo_empresa_screen.dart';
import 'presentation/screens/espera_aprobacion_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://eftbmrgoniwytqhcpgdf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVmdGJtcmdvbml3eXRxaGNwZ2RmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyNzE4OTUsImV4cCI6MjA5Njg0Nzg5NX0.aRkeTkA9cfrOj4SgOLYb8DcZ7iU9LWlWpjp-07ymoTs',
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AutoNCFApp());
}

class AutoNCFApp extends StatefulWidget {
  const AutoNCFApp({super.key});

  @override
  State<AutoNCFApp> createState() => _AutoNCFAppState();
}

class _AutoNCFAppState extends State<AutoNCFApp> {
  final _client = Supabase.instance.client;
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authStateSubscription;
  bool _listenerConfigurado = false;

  @override
  void initState() {
    super.initState();
    _configurarEscuchadorAutenticacion();
  }

  /// 🚀 BLINDADO ANTI-CASTEOS PARA FLUTTER WEB / NETLIFY
  void _configurarEscuchadorAutenticacion() {
    _authStateSubscription = _client.auth.onAuthStateChange.listen((data) async {
      final Session? session = data.session;
      final AuthChangeEvent event = data.event;

      if ((event == AuthChangeEvent.signedIn || session != null) && !_listenerConfigurado) {
        _listenerConfigurado = true;

        try {
          final user = session?.user ?? _client.auth.currentUser;
          if (user == null) {
            _listenerConfigurado = false;
            return;
          }

          // 🛡️ Consulta relacional limpia por ID
          final response = await _client
              .from('usuarios_empresas')
              .select('estado, rol')
              .eq('usuario_id', user.id);

          if (!mounted) return;

          // ✅ CORREGIDO: Mapeo seguro usando List.from() para evitar el colapso del main.dart.js en la Web
          final List<dynamic> relaciones = List.from(response as Iterable);

          // Si el usuario no tiene ninguna vinculación registrada en el sistema, va a vincularse
          if (relaciones.isEmpty) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => VinculoEmpresaScreen(usuarioId: user.id)),
                  (route) => false,
            );
            return;
          }

          // Analizamos si alguna de sus relaciones corporativas está activa o aprobada
          final bool esAprobadoOAdmin = relaciones.any((r) {
            final String estado = (r['estado'] ?? 'pendiente').toString().trim().toLowerCase();
            final String rol = (r['rol'] ?? 'operador').toString().trim().toLowerCase();
            return estado == 'aprobado' || estado == 'approved' || rol == 'admin';
          });

          final bool esPendiente = relaciones.any((r) {
            final String estado = (r['estado'] ?? 'pendiente').toString().trim().toLowerCase();
            return estado == 'pendiente' || estado == 'pending';
          });

          if (esAprobadoOAdmin) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainNavigator()),
                  (route) => false,
            );
          } else if (esPendiente) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => EsperaAprobacionScreen(usuarioId: user.id)),
                  (route) => false,
            );
          } else {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => VinculoEmpresaScreen(usuarioId: user.id)),
                  (route) => false,
            );
          }
        } catch (e) {
          // 🔎 Si hay un fallo de políticas RLS o red, se imprimirá de forma explícita en tu F12
          print("❌ Fallo crítico en el enrutamiento de AutoNCF: $e");
        } finally {
          _listenerConfigurado = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Session? session = _client.auth.currentSession;

    return MaterialApp(
      title: 'AutoNCF DGII',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF01579B),
        brightness: Brightness.light,
      ),
      home: session != null ? const MainNavigator() : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainNavigator(),
      },
    );
  }
}