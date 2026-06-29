import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'main_navigator.dart';

class VinculoEmpresaScreen extends StatefulWidget {
  final String usuarioId;
  const VinculoEmpresaScreen({super.key, required this.usuarioId});

  @override
  State<VinculoEmpresaScreen> createState() => _VinculoEmpresaScreenState();
}

class _VinculoEmpresaScreenState extends State<VinculoEmpresaScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  final _rncController = TextEditingController();
  final _nombreEmpresaController = TextEditingController();
  final _emailAdminController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rncController.dispose();
    _nombreEmpresaController.dispose();
    _emailAdminController.dispose();
    super.dispose();
  }

  Future<void> _asegurarPerfilUsuario() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final userEmail = user.email ?? '';
    final nombreUsuario = user.userMetadata?['full_name'] ?? 'Usuario Registrado';

    await _supabase.from('perfiles_usuarios').upsert({
      'id': user.id,
      'nombre_completo': nombreUsuario,
      'correo': userEmail,
      'rol': 'operador',
    });
  }

  void _crearNuevaEmpresa() async {
    String rnc = _rncController.text.trim();
    String nombre = _nombreEmpresaController.text.trim();
    final userEmail = _supabase.auth.currentUser?.email;

    if (rnc.isEmpty || nombre.isEmpty) {
      _mostrarAlerta("Todos los campos son obligatorios para registrar la empresa.");
      return;
    }

    if (userEmail == null) {
      _mostrarAlerta("No se detectó una sesión activa para autenticar la empresa.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _asegurarPerfilUsuario();

      // Validamos si este administrador ya tiene una empresa en Supabase
      final empresaExistente = await _supabase
          .from('empresas')
          .select('id')
          .eq('correo_admin', userEmail)
          .maybeSingle();

      if (empresaExistente != null) {
        setState(() => _isLoading = false);
        _mostrarAlerta("Tu cuenta de correo ya tiene una empresa registrada.");
        return;
      }

      // ✨ NATIVO: Insertamos la empresa directamente en Supabase (Sin Google Sheets ni Drive)
      final nuevaEmpresa = await _supabase.from('empresas').insert({
        'rnc': rnc,
        'nombre': nombre,
        'correo_admin': userEmail,
        'creado_por': widget.usuarioId,
      }).select().single();

      // Vinculamos al creador como el Administrador aprobado de la empresa
      await _supabase.from('usuarios_empresas').insert({
        'usuario_id': widget.usuarioId,
        'empresa_id': nuevaEmpresa['id'],
        'rol': 'admin',
        'estado': 'aprobado', // 🚀 CORREGIDO: De 'approved' a 'aprobado'
      });

      setState(() => _isLoading = false);
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigator()),
            (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarAlerta("Error al registrar la empresa de forma interna: $e");
    }
  }

  void _solicitarAccesoEmpresa() async {
    String emailAdmin = _emailAdminController.text.trim().toLowerCase();

    if (emailAdmin.isEmpty) {
      _mostrarAlerta("Por favor, introduce el correo electrónico del administrador.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _asegurarPerfilUsuario();

      final empresaTarget = await _supabase
          .from('empresas')
          .select('id, nombre')
          .eq('correo_admin', emailAdmin)
          .maybeSingle();

      if (empresaTarget == null) {
        setState(() => _isLoading = false);
        _mostrarAlerta("No se encontró ninguna empresa registrada con el correo de ese administrador.");
        return;
      }

      // Solicitud enlazada a la tabla relacional nativa
      await _supabase.from('usuarios_empresas').insert({
        'usuario_id': widget.usuarioId,
        'empresa_id': empresaTarget['id'],
        'rol': 'operador',
        'estado': 'pendiente',
      });

      setState(() => _isLoading = false);
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Solicitud Enviada'),
          content: Text('Tu solicitud para unirte a "${empresaTarget['nombre']}" ha sido registrada. Por favor, espera a que el administrador apruebe tu acceso.'),
          actions: [
            TextButton(
              onPressed: () async {
                await _supabase.auth.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              },
              child: const Text('Entendido'),
            )
          ],
        ),
      );

    } catch (e) {
      setState(() => _isLoading = false);
      if (e.toString().contains('duplicate key') || e.toString().contains('23505')) {
        _mostrarAlerta("Ya tienes una solicitud activa o un registro con esta empresa. Espera la aprobación del administrador.");
      } else {
        _mostrarAlerta("Error al procesar la solicitud de ingreso: $e");
      }
    }
  }

  void _mostrarAlerta(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('AutoNCF'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vinculación Corporativa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _supabase.auth.signOut();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF01579B),
          labelColor: const Color(0xFF01579B),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.add_business), text: "Soy Administrador"),
            Tab(icon: Icon(Icons.person_add_alt), text: "Soy Operador"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Icon(Icons.business_center, size: 60, color: Colors.blueGrey[800]),
                const SizedBox(height: 12),
                const Text('Registrar Nueva Empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Los datos fiscales se guardarán localmente en la app', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                TextField(
                  controller: _rncController,
                  decoration: const InputDecoration(labelText: 'RNC de la Empresa (9 u 11 dígitos)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nombreEmpresaController,
                  decoration: const InputDecoration(labelText: 'Nombre Comercial / Razón Social', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _crearNuevaEmpresa,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF01579B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Registrar y Fundar Empresa'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.assignment_ind, size: 60, color: Color(0xFF01579B)),
                const SizedBox(height: 12),
                const Text('Unirse a una Empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Introduce el correo del dueño de la empresa', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailAdminController,
                  decoration: const InputDecoration(
                    labelText: 'Correo Electrónico del Administrador',
                    border: OutlineInputBorder(),
                    hintText: 'ejemplo@empresa.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _solicitarAccesoEmpresa,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Enviar Solicitud de Ingreso'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}