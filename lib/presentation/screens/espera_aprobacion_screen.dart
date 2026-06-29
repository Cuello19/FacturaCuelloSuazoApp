import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'main_navigator.dart'; // 👈 Cambiado a MainNavigator para mantener tu flujo multi-empresa

class EsperaAprobacionScreen extends StatefulWidget {
  final String usuarioId;
  const EsperaAprobacionScreen({super.key, required this.usuarioId});

  @override
  State<EsperaAprobacionScreen> createState() => _EsperaAprobacionScreenState();
}

class _EsperaAprobacionScreenState extends State<EsperaAprobacionScreen> {
  final _client = Supabase.instance.client;
  late final RealtimeChannel _canalRealtime;

  @override
  void initState() {
    super.initState();
    _conectarCanalDeAprobacion();
  }

  void _conectarCanalDeAprobacion() {
    // 🔥 REPARADO: Ahora escucha de forma segura la tabla unificada correcta de tu nuevo Supabase
    _canalRealtime = _client
        .channel('public:usuarios_empresas:${widget.usuarioId}')
        .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'usuarios_empresas', // 👈 Apunta a tu tabla real
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'usuario_id',
          value: widget.usuarioId,
        ),
        callback: (payload) {
          // 🔥 REPARADO: Mapeo exacto de tu nueva columna 'estado'
          final String nuevoEstado = payload.newRecord['estado'] ?? 'pendiente';
          final String rol = payload.newRecord['rol'] ?? 'operador';

          if (nuevoEstado == 'aprobado' || rol == 'admin') {
            _canalRealtime.unsubscribe();
            if (mounted) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainNavigator()) // 👈 Maneja la UI de forma centralizada
              );
            }
          } else if (nuevoEstado == 'rechazado') {
            _canalRealtime.unsubscribe();
            if (mounted) {
              _mostrarCancelacion();
            }
          }
        })
        .subscribe();
  }

  void _mostrarCancelacion() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('❌ Tu solicitud fue rechazada por el administrador.'), backgroundColor: Colors.red),
    );
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  void dispose() {
    _client.removeChannel(_canalRealtime); // 👈 Limpieza más profunda del bus de datos
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(strokeWidth: 5, color: Colors.amber),
              ),
              const SizedBox(height: 32),
              const Text('Esperando Validación...', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 12),
              const Text(
                'Tu solicitud de vinculación está en la bandeja del Administrador de la empresa.\n\nTan pronto tu administrador te autorice desde su perfil, esta pantalla se desbloqueará automáticamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () {
                  _client.auth.signOut();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                icon: const Icon(Icons.arrow_back, color: Colors.red),
                label: const Text('Cancelar y Volver al Login', style: TextStyle(color: Colors.red)),
              )
            ],
          ),
        ),
      ),
    );
  }
}