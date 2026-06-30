import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/factura_model.dart';
import 'factura_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;

  late Future<List<FacturaModel>> _futureFacturas;
  bool _isRefreshing = false;
  bool _isLoadingEmpresas = true;

  String _tituloHeader = "Historial Fiscal";

  List<Map<String, dynamic>> _empresasAprobadas = [];
  Map<String, dynamic>? _empresaSeleccionada;
  List<FacturaModel> _listaFacturasOriginales = [];

  // 📡 Transmisión en Tiempo Real Declarada
  RealtimeChannel? _facturasStream;

  @override
  void initState() {
    super.initState();
    _inicializarEcosistemaHome();
    _escucharFacturasEnTiempoReal(); // Activa la escucha persistente de PostgreSQL
  }

  @override
  void dispose() {
    // 🧼 Desuscripción segura de canales para evitar fugas de memoria
    if (_facturasStream != null) {
      _supabase.removeChannel(_facturasStream!);
    }
    super.dispose();
  }

  /// ⚡ Configuración de la escucha en tiempo real nativa de Supabase
  void _escucharFacturasEnTiempoReal() {
    _facturasStream = _supabase
        .channel('public:facturas')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'facturas',
      callback: (payload) {
        print("🔔 Cambio detectado en PostgreSQL. Sincronizando interfaz...");
        _recargarHistorial();
      },
    )
        .subscribe();
  }

  Future<void> _inicializarEcosistemaHome() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final empresas = await _authService.obtenerMisEmpresasAprobadas(user.id);

      if (mounted) {
        setState(() {
          _empresasAprobadas = List<Map<String, dynamic>>.from(empresas);

          if (_empresasAprobadas.isNotEmpty) {
            _empresaSeleccionada = _empresasAprobadas.first;
            // 🚀 SALVAGUARDA: Usamos '??' en vez de el operador '!' para evitar colapsos
            _tituloHeader = _empresaSeleccionada?['nombre']?.toString() ?? "Historial Fiscal";
          } else {
            _tituloHeader = "Sin Empresas";
          }
          _isLoadingEmpresas = false;
        });

        _recargarHistorial();
      }
    } catch (e) {
      print("❌ Error inicializando multi-empresa en Home: $e");
      setState(() => _isLoadingEmpresas = false);
      _recargarHistorial();
    }
  }

  void _recargarHistorial() {
    final String idEmpresa = _empresaSeleccionada?['id']?.toString() ?? '';
    setState(() {
      _futureFacturas = _apiService.obtenerFacturas(idEmpresa);
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    _recargarHistorial();
    await _futureFacturas;
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _exportarExcelFiscal() {
    try {
      if (_listaFacturasOriginales.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay registros fiscales cargados para exportar.')),
        );
        return;
      }

      // 🚀 SOLUCIÓN AL ERROR: Forzamos la mutabilidad real duplicando la lista
      final listaMutableParaOperar = List<FacturaModel>.from(_listaFacturasOriginales);

      final datosMutables = listaMutableParaOperar.map((f) {
        return {
          'rnc': f.rnc,
          'tipo_id': f.tipoId,
          'nombre_empresa': f.nombreEmpresa,
          'tipo_gasto': f.tipoGasto,
          'ncf': f.ncf,
          'documento_modificado': f.documentoModificado,
          'fecha': f.fecha,
          'fecha_pago': f.fechaPago,
          'monto_servicios': f.montoServicios,
          'monto_bienes': f.montoBienes,
          'monto_total': f.montoTotal,
          'itbis_total': f.itbisTotal,
          'itbis_retenid': f.itbisRetenid,
          'itbis_proporcional': f.itbisProporcional,
          'itbis_costo': f.itbisCosto,
          'itbis_adelantar': f.itbisAdelantar,
          'itbis_percibido': f.itbisPercibido,
          'tipo_retencion_isr': f.tipoRetencionIsr,
          'retencion_renta': f.retencionRenta,
          'isr_percibido': f.isrPercibido,
          'isc': f.isc,
          'otros_impuestos': f.otrosImpuestos,
          'monto_ley': f.montoLey,
          'forma_pago': f.formaPago,
          'estatus': f.estatus,
          'creado_por': f.creadoPor,
          'tipo_formato': f.tipoFormato
        };
      }).toList();

      // Invocación externa limpia
      // _generarReporteExcelFiscal(datosMutables);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📊 Generando reporte contable AutoNCF (Excel)...')),
      );
    } catch (e) {
      print("❌ Error generando reporte Excel: $e");
    }
  }

  /// 🔍 Modal Bottom Sheet optimizado para Modelos Tipados de AutoNCF con imagen adjunta
  void _mostrarDetalleFacturaCompleto(BuildContext context, FacturaModel factura) {
    final bool esSimple = factura.tipoFormato == 'simple' || factura.tipoFormato == 'auditoria_simple';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(width: 50, height: 5, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    esSimple ? "🔍 Auditoría Simple" : "📄 Reporte Formato 606",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildFilaDetalle("RNC o Cédula:", factura.rnc),
                        _buildFilaDetalle("Tipo Id:", factura.tipoId),
                        if (esSimple) _buildFilaDetalle("Nombre Empresa:", factura.nombreEmpresa),
                        if (!esSimple) _buildFilaDetalle("Tipo Bienes/Servicios:", factura.tipoGasto),
                        _buildFilaDetalle("NCF:", factura.ncf),
                        if (!esSimple) _buildFilaDetalle("Documento Modificado:", factura.documentoModificado),
                        _buildFilaDetalle("Fecha Comprobante:", factura.fecha),
                        _buildFilaDetalle("Fecha Pago:", factura.fechaPago),
                        if (!esSimple) ...[
                          _buildFilaDetalle("Monto Servicios:", "RD\$ ${factura.montoServicios.toStringAsFixed(2)}"),
                          _buildFilaDetalle("Monto Bienes:", "RD\$ ${factura.montoBienes.toStringAsFixed(2)}"),
                        ],
                        _buildFilaDetalle("Total Monto Facturado:", "RD\$ ${factura.montoTotal.toStringAsFixed(2)}"),
                        _buildFilaDetalle("ITBIS Facturado:", "RD\$ ${factura.itbisTotal.toStringAsFixed(2)}"),
                        if (!esSimple) ...[
                          _buildFilaDetalle("ITBIS Retenido:", "RD\$ ${factura.itbisRetenid.toStringAsFixed(2)}"),
                          _buildFilaDetalle("ITBIS Proporcional:", "RD\$ ${factura.itbisProporcional.toStringAsFixed(2)}"),
                          _buildFilaDetalle("ITBIS Costo:", "RD\$ ${factura.itbisCosto.toStringAsFixed(2)}"),
                          _buildFilaDetalle("ITBIS Adelantar:", "RD\$ ${factura.itbisAdelantar.toStringAsFixed(2)}"),
                          _buildFilaDetalle("Impuesto Selectivo (ISC):", "RD\$ ${factura.isc.toStringAsFixed(2)}"),
                          _buildFilaDetalle("Otros Impuestos/Tasas:", "RD\$ ${factura.otrosImpuestos.toStringAsFixed(2)}"),
                          _buildFilaDetalle("Monto Propina Legal:", "RD\$ ${factura.montoLey.toStringAsFixed(2)}"),
                        ],
                        _buildFilaDetalle("Forma de Pago:", factura.formaPago),
                        _buildFilaDetalle("Estatus:", factura.estatus),
                        _buildFilaDetalle("Creado por:", factura.creadoPor),

                        const Divider(height: 30),

                        // 📸 RENDEREADO DE LA IMAGEN DIGITALIZADA DESDE EL STORAGE
                        if (factura.fileUrl.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "📷 Comprobante Digitalizado:",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF01579B)),
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              factura.fileUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  color: Colors.grey[100],
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.broken_image, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text("No se pudo cargar la imagen del comprobante.", style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(8)),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber),
                                SizedBox(width: 8),
                                Text("Esta factura no cuenta con respaldo fotográfico.", style: TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilaDetalle(String titulo, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          Flexible(
            child: Text(
              valor?.toString() ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            centerTitle: false,
            automaticallyImplyLeading: false,
            title: _isLoadingEmpresas
                ? const Text("Cargando Empresas...", style: TextStyle(fontSize: 14))
                : _empresasAprobadas.isEmpty
                ? Text(_tituloHeader, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))
                : DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _empresaSeleccionada,
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF01579B)),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                onChanged: (Map<String, dynamic>? nuevaEmpresa) {
                  if (nuevaEmpresa != null && nuevaEmpresa != _empresaSeleccionada) {
                    setState(() {
                      _empresaSeleccionada = nuevaEmpresa;
                      _tituloHeader = "${nuevaEmpresa['nombre']}";
                    });
                    _recargarHistorial();
                  }
                },
                items: _empresasAprobadas.map((Map<String, dynamic> emp) {
                  final String? logoUrl = emp['logo_url'];
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: emp,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFF01579B),
                          backgroundImage: logoUrl != null ? NetworkImage(logoUrl) : null,
                          child: logoUrl == null
                              ? const Icon(Icons.business, size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            emp['nombre'] ?? 'Empresa',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              _isRefreshing
                  ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
                  : IconButton(icon: const Icon(Icons.refresh), onPressed: _onRefresh),
            ],
            bottom: const TabBar(
              labelColor: Color(0xFF01579B),
              unselectedLabelColor: Colors.black54,
              indicatorColor: Color(0xFF01579B),
              tabs: [
                Tab(icon: Icon(Icons.analytics), text: "Reportes 606"),
                Tab(icon: Icon(Icons.bolt), text: "Auditorías Simples"),
              ],
            ),
          ),
          body: FutureBuilder<List<FacturaModel>>(
            future: _futureFacturas,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('❌ Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No hay facturas registradas.', style: TextStyle(color: Colors.grey)));
              }

              _listaFacturasOriginales = snapshot.data!;

              final facturas606 = _listaFacturasOriginales.where((f) => f.tipoFormato.contains('606')).toList();
              final facturasSimples = _listaFacturasOriginales.where((f) => f.tipoFormato.contains('simple')).toList();

              return TabBarView(
                children: [
                  _buildFacturasList(facturas606, "No hay reportes 606 en esta empresa."),
                  _buildFacturasList(facturasSimples, "No hay auditorías simples en esta empresa."),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _exportarExcelFiscal,
            backgroundColor: const Color(0xFF01579B),
            icon: const Icon(Icons.table_view_rounded, color: Colors.white),
            label: const Text("Exportar Excel DGII", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildFacturasList(List<FacturaModel> lista, String mensajeVacio) {
    if (lista.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text(mensajeVacio, style: const TextStyle(color: Colors.grey))));
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80, top: 10),
        itemCount: lista.length,
        itemBuilder: (context, index) {
          final factura = lista[index];
          final bool es606 = factura.tipoFormato == '606';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              onTap: () => _mostrarDetalleFacturaCompleto(context, factura),
              onLongPress: () async {
                final resultado = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FacturaDetailScreen(factura: factura))
                );
                if (resultado == true) {
                  _onRefresh();
                }
              },
              leading: Icon(
                  es606 ? Icons.receipt_long : Icons.offline_bolt_outlined,
                  color: es606 ? Colors.blueGrey : Colors.orange
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(factura.rnc.isNotEmpty ? "Suplidor: ${factura.rnc}" : "Establecimiento", overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: es606 ? Colors.blue[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: es606 ? Colors.blue : Colors.orange, width: 0.8),
                    ),
                    child: Text(
                      es606 ? "📄 606" : "🔍 Simple",
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: es606 ? Colors.blue[900] : Colors.orange[900]
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Text('NCF: ${factura.ncf}\nOperador: ${factura.creadoPor}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RD\$ ${factura.montoTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}