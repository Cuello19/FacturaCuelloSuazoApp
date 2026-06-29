import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/auth_service.dart';
import 'login_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _client = Supabase.instance.client;
  final _authService = AuthService();

  Map<String, dynamic>? _perfilData;
  List<dynamic> _misEmpresasAprobadas = []; // 🔥 MULTI-EMPRESA: Lista dinámica de empresas para el operador
  List<dynamic> _solicitudesPendientes = [];
  List<dynamic> _empleadosActivos = [];

  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isUploadingFoto = false;

  StreamSubscription<List<Map<String, dynamic>>>? _solicitudesSubscription;

  @override
  void initState() {
    super.initState();
    _cargarEcosistemaPerfil();
  }

  @override
  void dispose() {
    _solicitudesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _cargarEcosistemaPerfil() async {
    if (!mounted) return;

    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      final perfil = await _client
          .from('perfiles_usuarios')
          .select('nombre_completo, correo, avatar_url')
          .eq('id', user.id)
          .single();

      _perfilData = perfil;

      // 🔥 MULTI-EMPRESA: Traemos todas las relaciones corporativas del usuario actual sin singles restrictivos
      final relaciones = await _client
          .from('usuarios_empresas')
          .select('rol, estado, empresa_id, empresas(id, rnc, nombre, logo_url)')
          .eq('usuario_id', user.id);

      final listaRelaciones = List<Map<String, dynamic>>.from(relaciones);
      final esAdminEnAlguna = listaRelaciones.any((element) => element['rol'] == 'admin');

      if (esAdminEnAlguna) {
        _isAdmin = true;
        final relacionAdmin = listaRelaciones.firstWhere((element) => element['rol'] == 'admin');

        if (relacionAdmin['empresas'] != null) {
          _misEmpresasAprobadas = [relacionAdmin['empresas']];
        }

        final String empresaId = relacionAdmin['empresa_id']?.toString() ?? '';
        if (empresaId.isNotEmpty) {
          await _recargarDatosInternos(empresaId);

          _solicitudesSubscription?.cancel();
          _solicitudesSubscription = _authService.escucharSolicitudesEmpresa(empresaId).listen((snapshot) {
            print("🚀 Stream de Admin recibió actualización: ${snapshot.length} filas");
            _procesarListaUsuarios(snapshot);
          });
        }
      } else {
        _isAdmin = false;
        // 🔥 OPERADOR: Filtramos e inyectamos dinámicamente el listado de empresas aprobadas activas
        _misEmpresasAprobadas = listaRelaciones
            .where((e) => e['estado'] != null && e['estado'].toString().trim() == 'aprobado' && e['empresas'] != null)
            .map((e) => e['empresas'])
            .toList();

        // Salvaguarda: si no tiene aprobadas pero hay registros en curso, mostramos la primera para poblar la UI inicial
        if (_misEmpresasAprobadas.isEmpty && listaRelaciones.isNotEmpty) {
          _misEmpresasAprobadas = [listaRelaciones.first['empresas']];
        }
      }
    } catch (e) {
      print("Error cargando ecosistema de perfil: $e");
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 REPARADO CON TOTAL BLINDAJE ANTI-NULOS: Evita el colapso por casteo estricto de tipos de datos
  void _procesarListaUsuarios(List<Map<String, dynamic>> listaCompleta) {
    if (!mounted) return;

    setState(() {
      _solicitudesPendientes = listaCompleta
          .where((element) =>
      element['estado'] != null &&
          element['estado'].toString().trim() == 'pendiente')
          .map((sol) {
        final perfilOp = sol['perfiles_usuarios'] as Map<String, dynamic>?;
        return {
          'relacion_id': sol['id']?.toString() ?? '',
          'usuario_id': sol['usuario_id']?.toString() ?? '',
          'nombre_completo': perfilOp?['nombre_completo']?.toString() ?? 'Operador en Espera',
          'correo': perfilOp?['correo']?.toString() ?? 'Sin correo',
        };
      }).toList();

      _empleadosActivos = listaCompleta
          .where((element) =>
      element['estado'] != null &&
          element['estado'].toString().trim() == 'aprobado' &&
          element['rol'] != null &&
          element['rol'].toString().trim() == 'operador')
          .map((m) {
        final perfilOp = m['perfiles_usuarios'] as Map<String, dynamic>?;
        return {
          'relacion_id': m['id']?.toString() ?? '',
          'usuario_id': m['usuario_id']?.toString() ?? '',
          'nombre_completo': perfilOp?['nombre_completo']?.toString() ?? 'Operador Activo',
          'correo': perfilOp?['correo']?.toString() ?? '',
        };
      }).toList();

      print("✅ UI Actualizada: ${_solicitudesPendientes.length} pendientes, ${_empleadosActivos.length} activos");
    });
  }

  Future<void> _recargarDatosInternos(String empresaId) async {
    try {
      final solicitudes = await _client
          .from('usuarios_empresas')
          .select('id, usuario_id, estado, rol, perfiles_usuarios!usuarios_empresas_usuario_id_fkey(nombre_completo, correo)')
          .eq('empresa_id', empresaId);

      _procesarListaUsuarios(List<Map<String, dynamic>>.from(solicitudes));
    } catch (e) {
      print("Error recargando datos relacionales internos: $e");
    }
  }

  void _mostrarDialogoSolicitarEmpresa() {
    final TextEditingController correoController = TextEditingController();
    bool subiendoSolicitud = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Vincular Nueva Empresa', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el correo del administrador de la empresa a la que deseas unirte como operador.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo del Admin',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: subiendoSolicitud ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: subiendoSolicitud
                    ? null
                    : () async {
                  final correo = correoController.text.trim();
                  if (correo.isEmpty) return;

                  setModalState(() => subiendoSolicitud = true);

                  final empresa = await _authService.buscarEmpresaPorCorreoAdmin(correo);

                  if (empresa == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('❌ No se encontró ninguna empresa con ese administrador.')),
                      );
                    }
                    setModalState(() => subiendoSolicitud = false);
                    return;
                  }

                  final user = _client.auth.currentUser;
                  final exito = await _authService.enviarSolicitudNuevaEmpresa(
                    usuarioId: user!.id,
                    empresaId: empresa['id'],
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    if (exito) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('📩 Solicitud enviada con éxito a ${empresa['nombre']}.')),
                      );
                      _cargarEcosistemaPerfil();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('⚠️ Ya tienes una vinculación activa o pendiente con esta empresa.')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF01579B), foregroundColor: Colors.white),
                child: subiendoSolicitud
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cambiarFotoPerfil() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (imagen == null) return;

      setState(() => _isUploadingFoto = true);

      final Uint8List bytes = await imagen.readAsBytes();
      final String fileExtension = imagen.name.split('.').last;
      final String finalPath = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await _client.storage.from('avatars').uploadBinary(
        finalPath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final String urlPublica = _client.storage.from('avatars').getPublicUrl(finalPath);

      await _client.from('perfiles_usuarios').update({
        'avatar_url': urlPublica,
      }).eq('id', user.id);

      await _cargarEcosistemaPerfil();
      _mostrarSnackBar('✅ Foto de perfil sincronizada en la nube');
    } catch (e) {
      _mostrarAlerta("Error al subir imagen de perfil: $e");
    } finally {
      if (mounted) setState(() => _isUploadingFoto = false);
    }
  }

  Future<void> _cambiarLogoEmpresa(String idEmpresaReal) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (imagen == null) return;

      _mostrarSnackBar('Subiendo logo corporativo...');

      final Uint8List bytes = await imagen.readAsBytes();
      final String fileExtension = imagen.name.split('.').last;
      final String finalPath = '$idEmpresaReal/logo_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await _client.storage.from('logos').uploadBinary(
        finalPath,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final String urlPublicaLogo = _client.storage.from('logos').getPublicUrl(finalPath);

      await _client.from('empresas').update({
        'logo_url': urlPublicaLogo,
      }).eq('id', idEmpresaReal);

      await _cargarEcosistemaPerfil();
      _mostrarSnackBar('✅ Logo corporativo actualizado con éxito');
    } catch (e) {
      _mostrarAlerta("Error al actualizar el logo de la empresa: $e");
    }
  }

  Future<void> _procesarSolicitud(String relacionId, String nuevoEstado) async {
    try {
      await _client
          .from('usuarios_empresas')
          .update({'estado': nuevoEstado})
          .eq('id', relacionId);
      await _cargarEcosistemaPerfil();
    } catch (e) {
      print("Error procesando solicitud de acceso: $e");
    }
  }

  Future<void> _eliminarEmpleado(String relacionId, String nombre) async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Miembro'),
        content: Text('¿Seguro que deseas revocar el acceso a $nombre?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _client
            .from('usuarios_empresas')
            .update({'estado': 'rechazado'})
            .eq('id', relacionId);
        await _cargarEcosistemaPerfil();
      } catch (e) {
        print("Error Docs miembro: $e");
      }
    }
  }

  void _cerrarSesionCompleta() async {
    await _authService.cerrarSesion();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _mostrarSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _mostrarAlerta(String msg) {
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
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final String? avatarUrl = _perfilData?['avatar_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta Corporativa'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingFoto ? null : _cambiarFotoPerfil,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: const Color(0xFF01579B),
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null && _isUploadingFoto == false
                                ? Text(
                              _perfilData?['nombre_completo']?[0].toUpperCase() ?? "U",
                              style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                            )
                                : null,
                          ),
                          if (_isUploadingFoto)
                            const Positioned.fill(
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            ),
                          const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.edit, size: 14, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_perfilData?['nombre_completo'] ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          Text(_perfilData?['correo'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 6),
                          Chip(
                            label: Text(
                              _isAdmin ? "ADMINISTRADOR" : "OPERADOR MULTI-EMPRESA",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            backgroundColor: _isAdmin ? Colors.amber[800] : Colors.blueGrey,
                            visualDensity: VisualDensity.compact,
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                'Mis Empresas Aprobadas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 8),

            _misEmpresasAprobadas.isEmpty
                ? const Card(
              color: Colors.white,
              child: ListTile(
                leading: Icon(Icons.business_outlined, color: Colors.grey),
                title: Text('Ninguna empresa vinculada actualmente', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _misEmpresasAprobadas.length,
              itemBuilder: (context, index) {
                final emp = _misEmpresasAprobadas[index];
                final String nombre = emp?['nombre'] ?? "Sin Nombre";
                final String rnc = emp?['rnc'] ?? "N/A";
                final String? logo = emp?['logo_url'];

                return Card(
                  elevation: 1,
                  color: Colors.blueGrey[50],
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: GestureDetector(
                        onTap: _isAdmin ? () => _cambiarLogoEmpresa(emp['id']?.toString() ?? '') : null,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(0xFF01579B),
                              backgroundImage: logo != null ? NetworkImage(logo) : null,
                              child: logo == null
                                  ? const Icon(Icons.business, color: Colors.white, size: 22)
                                  : null,
                            ),
                            if (_isAdmin)
                              const CircleAvatar(
                                radius: 8,
                                backgroundColor: Colors.amber,
                                child: Icon(Icons.add_a_photo, size: 8, color: Colors.black),
                              ),
                          ],
                        ),
                      ),
                      title: Text(nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                      subtitle: Text('RNC: $rnc', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      trailing: _isAdmin
                          ? const Text('Gestionar Logo', style: TextStyle(color: Color(0xFF01579B), fontSize: 10, fontWeight: FontWeight.bold))
                          : const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    ),
                  ),
                );
              },
            ),

            if (!_isAdmin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _mostrarDialogoSolicitarEmpresa,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Solicitar unirse a otra empresa', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: const Color(0xFF01579B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
              ),
            ],

            const Divider(height: 32),
            const SizedBox(height: 12),

            if (_isAdmin) ...[
              Row(
                children: [
                  const Icon(Icons.notification_important, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Solicitudes de Acceso Pendientes (${_solicitudesPendientes.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _solicitudesPendientes.isEmpty
                  ? const Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green),
                      SizedBox(width: 12),
                      Text('No hay empleados esperando acceso.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _solicitudesPendientes.length,
                itemBuilder: (context, index) {
                  final solicitud = _solicitudesPendientes.length > index ? _solicitudesPendientes[index] : null;
                  if (solicitud == null) return const SizedBox();
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(solicitud['nombre_completo']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(solicitud['correo']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _procesarSolicitud(solicitud['relacion_id']?.toString() ?? '', 'rechazado'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => _procesarSolicitud(solicitud['relacion_id']?.toString() ?? '', 'aprobado'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.people, color: Color(0xFF01579B)),
                  const SizedBox(width: 8),
                  Text(
                    'Miembros de la Empresa (${_empleadosActivos.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _empleadosActivos.isEmpty
                  ? const Card(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blueGrey),
                      SizedBox(width: 12),
                      Text('No tienes operadores vinculados aún.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _empleadosActivos.length,
                itemBuilder: (context, index) {
                  final empleado = _empleadosActivos[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 1,
                    child: ListTile(
                      title: Text(empleado['nombre_completo']?.toString() ?? 'Operador', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(empleado['correo']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                        tooltip: 'Desvincular Miembro',
                        onPressed: () => _eliminarEmpleado(empleado['relacion_id']?.toString() ?? '', empleado['nombre_completo']?.toString() ?? 'este usuario'),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _cerrarSesionCompleta,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}