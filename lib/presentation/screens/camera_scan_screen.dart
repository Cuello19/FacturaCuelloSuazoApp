import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/api_service.dart'; // Asegúrate de que la ruta apunte a tu ApiService

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final _supabase = Supabase.instance.client;
  final ApiService _apiService = ApiService(); // Instanciamos tu servicio centralizado

  final List<XFile> _colaDeFacturas = [];
  bool _estaProcesando = false;
  String _mensajeProgreso = "";
  double _progresoPorcentaje = 0.0;

  List<Map<String, dynamic>> _misEmpresas = [];
  Map<String, dynamic>? _empresaSeleccionada;

  String _tipoEscaneo = "606";
  bool _cargandoConfiguracion = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionesUsuario();
  }

  void _cargarConfiguracionesUsuario() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabase
            .from('usuarios_empresas')
            .select('estado, rol, empresas (id, rnc, nombre)')
            .eq('usuario_id', user.id);

        final List<dynamic> data = response as List<dynamic>;

        if (mounted) {
          setState(() {
            _misEmpresas = data
                .where((element) =>
            element['empresas'] != null &&
                (element['estado'] == 'aprobado' || element['estado'] == 'approved' || element['rol'] == 'admin')
            )
                .map((element) => element['empresas'] as Map<String, dynamic>)
                .toList();

            if (_misEmpresas.isNotEmpty) {
              _empresaSeleccionada = _misEmpresas.first;
            }
            _cargandoConfiguracion = false;
          });
        }
      }
    } catch (e) {
      print("Error cargando empresas asociadas: $e");
      if (mounted) setState(() => _cargandoConfiguracion = false);
    }
  }

  Future<void> _tomarFoto() async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (foto != null) {
        setState(() {
          _colaDeFacturas.add(foto);
        });
        _mostrarMensaje("Comprobante capturado y añadido a la lista");
      }
    } catch (e) {
      _mostrarAlerta("Error al abrir la cámara: $e");
    }
  }

  Future<void> _seleccionarDeGaleria() async {
    try {
      final List<XFile> imagenesSeleccionadas = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      if (imagenesSeleccionadas.isNotEmpty) {
        setState(() {
          _colaDeFacturas.addAll(imagenesSeleccionadas);
        });
        _mostrarMensaje("Se agregaron ${imagenesSeleccionadas.length} imágenes");
      }
    } catch (e) {
      _mostrarAlerta("Error al acceder a la galería: $e");
    }
  }

  /// 🚀 MIGRACIÓN COMPLETA AUTOMATIZADA: Consume el backend enviando la imagen por partes directo a Node.js
  Future<void> _procesarLoteAutoNCF() async {
    if (_colaDeFacturas.isEmpty || _empresaSeleccionada == null) {
      _mostrarAlerta("Asegúrate de tener facturas en la cola y una empresa activa.");
      return;
    }

    setState(() {
      _estaProcesando = true;
      _progresoPorcentaje = 0.0;
    });

    int totalProcesar = _colaDeFacturas.length;
    int procesadasConExito = 0;
    final user = _supabase.auth.currentUser;
    final String nombreOperador = user?.userMetadata?['full_name'] ?? user?.email ?? "Operador Activo";

    for (int i = 0; i < totalProcesar; i++) {
      final XFile imagenActual = _colaDeFacturas[i];

      setState(() {
        _mensajeProgreso = "Enviando e indexando comprobante ${i + 1} de $totalProcesar con Gemini AI...";
        _progresoPorcentaje = i / totalProcesar;
      });

      // Delegamos el flujo binario completo y el análisis de visión a nuestro ApiService homologado
      final bool exito = await _apiService.enviarFacturaAlBackend(
        imagen: imagenActual,
        empresaId: _empresaSeleccionada!['id'].toString(),
        tipoFormato: _tipoEscaneo,
        creadoPor: nombreOperador,
      );

      if (exito) {
        procesadasConExito++;
      }
    }

    setState(() {
      _colaDeFacturas.clear();
      _estaProcesando = false;
      _progresoPorcentaje = 1.0;
    });

    _mostrarModalFinLote(totalProcesar, procesadasConExito);
  }

  void _eliminarDeCola(int index) {
    setState(() {
      _colaDeFacturas.removeAt(index);
    });
  }

  void _mostrarMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  void _mostrarAlerta(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AutoNCF'),
        content: Text(mensaje),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _mostrarModalFinLote(int total, int exitosas) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Procesamiento de Lote'),
          ],
        ),
        content: Text('Sincronización de auditoría finalizada:\n\n'
            '• Enviadas desde el dispositivo: $total\n'
            '• Procesadas con éxito por la IA: $exitosas\n'
            '• Facturas fallidas/ilegibles: ${total - exitosas}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoConfiguracion) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga Masiva AutoNCF'),
        backgroundColor: Colors.grey[100],
        foregroundColor: const Color(0xFF01579B),
        elevation: 0,
        centerTitle: true,
      ),
      body: _estaProcesando
          ? _buildProgressIndicator()
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSelectoresConfiguracion(),
            const SizedBox(height: 16),
            _buildQueueHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: _colaDeFacturas.isEmpty
                  ? _buildEmptyState()
                  : _buildQueueListView(),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectoresConfiguracion() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.business, color: Color(0xFF01579B), size: 22),
              const SizedBox(width: 12),
              const Text("Empresa:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: _misEmpresas.isEmpty
                    ? const Text("Sin empresas aprobadas", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                    : DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _empresaSeleccionada,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
                    items: _misEmpresas.map((empresa) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: empresa,
                        child: Text("${empresa['nombre']}"),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _empresaSeleccionada = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 16, thickness: 1),
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFF01579B), size: 22),
              const SizedBox(width: 12),
              const Text("Formato:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tipoEscaneo,
                    isExpanded: true,
                    style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w500),
                    items: const [
                      DropdownMenuItem(value: "606", child: Text("Formato Completo 606")),
                      DropdownMenuItem(value: "simple", child: Text("Auditoría Simple (RNC, NCF, Totales)")),
                    ],
                    onChanged: (val) {
                      setState(() => _tipoEscaneo = val ?? "606");
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 5, color: Color(0xFF01579B)),
            const SizedBox(height: 24),
            Text(
              _mensajeProgreso,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _progresoPorcentaje, color: const Color(0xFF01579B)),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Comprobantes en lista de espera", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        Chip(
          label: Text("${_colaDeFacturas.length} Items", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF01579B),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.collections_bookmark_outlined, size: 75, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text("La cola de envío está vacía", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildQueueListView() {
    return ListView.separated(
      itemCount: _colaDeFacturas.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Card(
          elevation: 1,
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Color(0xFF01579B)),
            title: Text("Factura Digital #${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            trailing: IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              onPressed: () => _eliminarDeCola(index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _tomarFoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Cámara'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _seleccionarDeGaleria,
                icon: const Icon(Icons.photo_library),
                label: const Text('Galería'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
        if (_colaDeFacturas.isNotEmpty) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _procesarLoteAutoNCF,
            icon: const Icon(Icons.cloud_upload),
            label: Text('Enviar Lote a $_tipoEscaneo'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52), backgroundColor: const Color(0xFF01579B), foregroundColor: Colors.white),
          ),
        ]
      ],
    );
  }
}