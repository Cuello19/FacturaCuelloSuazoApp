import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Iniciar sesión con Google (OAuth)
  Future<bool> signInWithGoogle() async {
    try {
      return await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://callback',
      );
    } catch (e) {
      print("Error en Google Sign-In: $e");
      return false;
    }
  }

  /// Iniciar sesión ordinaria por correo y contraseña
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return {'success': false, 'error': 'Credenciales inválidas'};
      }

      final estatus = await verificarEstatusSolicitud(response.user!.id);
      return {'success': true, 'user': response.user, 'estatus_acceso': estatus};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Registrar nuevo usuario en la tabla central de autenticación
  Future<Map<String, dynamic>> registrarUsuario({
    required String email,
    required String password,
    required String nombre,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return {'success': false, 'error': 'Error al crear la cuenta'};
      }

      await _client.from('perfiles_usuarios').insert({
        'id': response.user!.id,
        'nombre_completo': nombre,
        'correo': email,
        'rol': 'operador',
      });

      return {'success': true, 'user': response.user};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 🔥 EVALUACIÓN ELÁSTICA MULTI-EMPRESA: Soporta 'aprobado' y 'approved' para evitar bucles
  Future<String> verificarEstatusSolicitud(String usuarioId) async {
    try {
      final response = await _client
          .from('usuarios_empresas')
          .select('estado, rol')
          .eq('usuario_id', usuarioId);

      final lista = List<Map<String, dynamic>>.from(response);

      if (lista.isEmpty) return 'sin_empresa';

      // Si es admin o está aprobado (en cualquier idioma) entra directo
      bool esAprobado = lista.any((e) =>
      e['rol'] == 'admin' ||
          e['estado'].toString().trim() == 'aprobado' ||
          e['estado'].toString().trim() == 'approved'
      );
      if (esAprobado) return 'aprobado';

      bool esPendiente = lista.any((e) =>
      e['estado'].toString().trim() == 'pendiente' ||
          e['estado'].toString().trim() == 'pending'
      );
      if (esPendiente) return 'pendiente';

      return 'rechazado';
    } catch (e) {
      print("❌ Error en verificarEstatusSolicitud: $e");
      return 'sin_empresa';
    }
  }

  /// 🔥 ESCUCHADOR EN TIEMPO REAL: OPERADOR
  Stream<List<Map<String, dynamic>>> escucharEstatusAcceso(String usuarioId) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    final canal = _client.channel('public:usuarios_empresas:$usuarioId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'usuarios_empresas',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'usuario_id',
        value: usuarioId,
      ),
      callback: (payload) async {
        final nuevoEstatus = await verificarEstatusSolicitud(usuarioId);

        if (!controller.isClosed) {
          controller.add([
            {
              'estado': nuevoEstatus,
              'rol': payload.newRecord['rol'] ?? 'operador',
            }
          ]);
        }
      },
    );

    canal.subscribe();

    controller.onCancel = () {
      _client.removeChannel(canal);
      controller.close();
    };

    return controller.stream;
  }

  /// 🔥 ESCUCHADOR EN TIEMPO REAL: ADMINISTRACIÓN DE EMPRESA
  Stream<List<Map<String, dynamic>>> escucharSolicitudesEmpresa(String empresaId) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    final canal = _client.channel('public:usuarios_empresas:empresa:$empresaId').onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'usuarios_empresas',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'empresa_id',
        value: empresaId,
      ),
      callback: (payload) async {
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          final snapshot = await _client
              .from('usuarios_empresas')
              .select('id, usuario_id, estado, rol, perfiles_usuarios!usuarios_empresas_usuario_id_fkey(nombre_completo, correo)')
              .eq('empresa_id', empresaId);

          if (!controller.isClosed) {
            controller.add(List<Map<String, dynamic>>.from(snapshot));
          }
        } catch (e) {
          print("❌ Error en stream de administración: $e");
        }
      },
    );

    canal.subscribe();

    controller.onCancel = () {
      _client.removeChannel(canal);
      controller.close();
    };

    return controller.stream;
  }

  /// 🔥 CORREGIDO: Trae las empresas unificando criterios de idioma y rol de manera directa
  Future<List<Map<String, dynamic>>> obtenerMisEmpresasAprobadas(String usuarioId) async {
    try {
      final response = await _client
          .from('usuarios_empresas')
          .select('estado, rol, empresas (id, rnc, nombre)')
          .eq('usuario_id', usuarioId);

      final List<dynamic> data = response as List<dynamic>;

      return data
          .where((e) => e['empresas'] != null && (e['estado'] == 'aprobado' || e['estado'] == 'approved' || e['rol'] == 'admin'))
          .map((e) => e['empresas'] as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print("Error obtener empresas aprobadas: $e");
      return [];
    }
  }

  /// Obtener los datos del perfil del usuario actual
  Future<Map<String, dynamic>?> obtenerPerfilActual() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      return await _client
          .from('perfiles_usuarios')
          .select()
          .eq('id', user.id)
          .single();
    } catch (e) {
      print("Error al obtener perfil: $e");
      return null;
    }
  }

  /// MULTI-EMPRESA: Buscar una empresa por el correo de su administrador
  Future<Map<String, dynamic>?> buscarEmpresaPorCorreoAdmin(String correoAdmin) async {
    try {
      final data = await _client
          .from('empresas')
          .select('id, nombre')
          .eq('correo_admin', correoAdmin.trim())
          .maybeSingle();
      return data;
    } catch (e) {
      print("❌ Error al buscar empresa por correo admin: $e");
      return null;
    }
  }

  /// MULTI-EMPRESA: Enviar una nueva solicitud de vinculación como operador
  Future<bool> enviarSolicitudNuevaEmpresa({
    required String usuarioId,
    required String empresaId,
  }) async {
    try {
      final existente = await _client
          .from('usuarios_empresas')
          .select('id')
          .eq('usuario_id', usuarioId)
          .eq('empresa_id', empresaId)
          .maybeSingle();

      if (existente != null) {
        return false;
      }

      await _client.from('usuarios_empresas').insert({
        'usuario_id': usuarioId,
        'empresa_id': empresaId,
        'rol': 'operador',
        'estado': 'pendiente',
      });
      return true;
    } catch (e) {
      print("❌ Error al enviar nueva solicitud: $e");
      return false;
    }
  }

  /// Cerrar Sesión limpia de la aplicación
  Future<void> cerrarSesion() async {
    await _client.auth.signOut();
  }
}