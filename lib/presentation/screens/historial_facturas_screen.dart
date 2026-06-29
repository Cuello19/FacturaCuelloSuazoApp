import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as estili_excel;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HistorialFacturasScreen extends StatefulWidget {
  const HistorialFacturasScreen({super.key});

  @override
  State<HistorialFacturasScreen> createState() => _HistorialFacturasScreenState();
}

class _HistorialFacturasScreenState extends State<HistorialFacturasScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<Map<String, dynamic>> _todasLasFacturas = [];
  List<Map<String, dynamic>> _misEmpresas = [];
  Map<String, dynamic>? _empresaSeleccionada;

  List<String> _anosDisponibles = [];
  Map<String, List<String>> _mesesPorAno = {};

  final Map<String, String> _nombresMeses = {
    '01': 'Enero', '02': 'Febrero', '03': 'Marzo', '04': 'Abril',
    '05': 'Mayo', '06': 'Junio', '07': 'Julio', '08': 'Agosto',
    '09': 'Septiembre', '10': 'Octubre', '11': 'Noviembre', '12': 'Diciembre'
  };

  @override
  void initState() {
    super.initState();
    _cargarEcosistemaHistorial();
  }

  Future<void> _cargarEcosistemaHistorial() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final responseEmpresas = await _supabase
          .from('usuarios_empresas')
          .select('estado, rol, empresas (id, rnc, nombre)')
          .eq('usuario_id', user.id);

      final List<dynamic> dataEmp = responseEmpresas as List<dynamic>;
      _misEmpresas = dataEmp
          .where((e) => e['empresas'] != null && (e['estado'] == 'aprobado' || e['estado'] == 'approved' || e['rol'] == 'admin'))
          .map((e) => e['empresas'] as Map<String, dynamic>)
          .toList();

      if (_misEmpresas.isNotEmpty) {
        _empresaSeleccionada = _misEmpresas.first;
        await _descargarFacturasDeEmpresa();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error inicializando historial: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarFacturasDeEmpresa() async {
    if (_empresaSeleccionada == null) return;
    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('facturas')
          .select('*')
          .eq('empresa_id', _empresaSeleccionada!['id'])
          .order('fecha', ascending: false);

      _todasLasFacturas = List<Map<String, dynamic>>.from(response as List);

      _anosDisponibles.clear();
      _mesesPorAno.clear();

      for (var f in _todasLasFacturas) {
        String? fecha = f['fecha'];
        if (fecha != null && fecha.length >= 7) {
          String ano = fecha.substring(0, 4);
          String mes = fecha.substring(5, 7);

          if (!_anosDisponibles.contains(ano)) {
            _anosDisponibles.add(ano);
          }
          if (!_mesesPorAno.containsKey(ano)) {
            _mesesPorAno[ano] = [];
          }
          if (!_mesesPorAno[ano]!.contains(mes)) {
            _mesesPorAno[ano]!.add(mes);
          }
        }
      }

      _anosDisponibles.sort((a, b) => b.compareTo(a));

      setState(() => _isLoading = false);
    } catch (e) {
      print("Error descargando facturas: $e");
      setState(() => _isLoading = false);
    }
  }

  /// 🚀 PARSEO DINÁMICO: Lee del JSONB e imprime las columnas estructuradas solicitadas
  Future<void> _exportarPeriodoAExcel(String ano, String mes, String tipoFormato) async {
    final facturasPeriodo = _todasLasFacturas.where((f) =>
    f['fecha'].toString().startsWith("$ano-$mes") && f['tipo_formato'] == tipoFormato
    ).toList();

    if (facturasPeriodo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay registros en este formato para exportar.")));
      return;
    }

    try {
      var excel = estili_excel.Excel.createExcel();
      String sheetName = "${tipoFormato.toUpperCase()}_$mes$ano";
      excel.rename('Sheet1', sheetName);
      estili_excel.Sheet sheet = excel[sheetName];

      estili_excel.CellStyle estiloHeader = estili_excel.CellStyle(
        backgroundColorHex: '#01579B',
        fontColorHex: '#FFFFFF',
        bold: true,
      );

      List<String> encabezados = [];
      if (tipoFormato == '606') {
        encabezados = [
          "RNC o Cédula", "Tipo Id", "Tipo Bienes y Servicios Comprados", "NCF",
          "NCF ó Documento Modificado", "Fecha Comprobante", "Fecha Pago",
          "Monto Facturado en Servicios", "Monto Facturado en Bienes", "Total Monto Facturado",
          "ITBIS Facturado", "ITBIS Retenido", "ITBIS sujeto a Proporcionalidad",
          "ITBIS llevado al Costo", "ITBIS por Adelantar", "ITBIS percibido en compras",
          "Tipo de Retención en ISR", "Monto Retención Renta", "ISR Percibido en compras",
          "Impuesto Selectivo al Consumo", "Otros Impuesto/Tasas", "Monto Propina Legal",
          "Forma de Pago", "Estatus", "creado_por"
        ];
      } else {
        encabezados = [
          "RNC o Cédula", "Tipo Id", "Nombre Empresa", "NCF", "Fecha Comprobante",
          "Fecha Pago", "Total Monto Facturado", "ITBIS Facturado", "Forma de Pago",
          "Estatus", "creado_por"
        ];
      }

      sheet.appendRow(encabezados);

      for (int col = 0; col < encabezados.length; col++) {
        var cell = sheet.cell(estili_excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.cellStyle = estiloHeader;
      }

      for (var f in facturasPeriodo) {
        // Extraemos el bloque relacional JSONB de Supabase
        final fiscalJson = f['datos_606'] as Map<String, dynamic>? ?? {};

        if (tipoFormato == '606') {
          sheet.appendRow([
            fiscalJson['rnc_o_cedula'] ?? f['rnc'] ?? '',
            fiscalJson['tipo_id'] ?? '1',
            fiscalJson['tipo_bienes_y_servicios_comprados'] ?? '02',
            fiscalJson['ncf'] ?? f['ncf'] ?? '',
            fiscalJson['ncf_o_documento_modificado'] ?? '',
            fiscalJson['fecha_comprobante'] ?? f['fecha'] ?? '',
            fiscalJson['fecha_pago'] ?? f['fecha'] ?? '',
            fiscalJson['monto_facturado_en_servicios'] ?? 0.0,
            fiscalJson['monto_facturado_en_bienes'] ?? 0.0,
            fiscalJson['total_monto_facturado'] ?? f['monto_total'] ?? 0.0,
            fiscalJson['itbis_facturado'] ?? f['itbis_total'] ?? 0.0,
            fiscalJson['itbis_retenido'] ?? 0.0,
            fiscalJson['itbis_sujeto_a_proporcionalidad'] ?? 0.0,
            fiscalJson['itbis_llevado_al_costo'] ?? 0.0,
            fiscalJson['itbis_por_adelantar'] ?? f['itbis_total'] ?? 0.0,
            fiscalJson['itbis_percibido_en_compras'] ?? 0.0,
            fiscalJson['tipo_de_retencion_en_isr'] ?? '',
            fiscalJson['monto_retencion_renta'] ?? 0.0,
            fiscalJson['isr_percibido_en_compras'] ?? 0.0,
            fiscalJson['impuesto_selectivo_al_consumo'] ?? 0.0,
            fiscalJson['otros_impuesto_tasas'] ?? 0.0,
            fiscalJson['monto_propina_legal'] ?? 0.0,
            fiscalJson['forma_de_pago'] ?? f['forma_pago'] ?? '01',
            f['estatus'] ?? 'VÁLIDO',
            f['creado_por'] ?? ''
          ]);
        } else {
          sheet.appendRow([
            fiscalJson['rnc_o_cedula'] ?? f['rnc'] ?? '',
            fiscalJson['tipo_id'] ?? '1',
            fiscalJson['nombre_empresa'] ?? 'Establecimiento Comercial',
            fiscalJson['ncf'] ?? f['ncf'] ?? '',
            fiscalJson['fecha_comprobante'] ?? f['fecha'] ?? '',
            fiscalJson['fecha_pago'] ?? f['fecha'] ?? '',
            fiscalJson['total_monto_facturado'] ?? f['monto_total'] ?? 0.0,
            fiscalJson['itbis_facturado'] ?? f['itbis_total'] ?? 0.0,
            fiscalJson['forma_de_pago'] ?? f['forma_pago'] ?? '01',
            f['estatus'] ?? 'VÁLIDO',
            f['creado_por'] ?? ''
          ]);
        }
      }

      var bytes = excel.encode();
      final dir = await getTemporaryDirectory();
      File file = File("${dir.path}/Reporte_${tipoFormato.toUpperCase()}_${mes}_${ano}.xlsx")
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!);

      await Share.shareXFiles([XFile(file.path)], text: 'Reporte fiscal generado exitosamente desde AutoNCF.');
    } catch (e) {
      print("Error generando reporte Excel: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildSelectorEmpresaHeader(),
        backgroundColor: Colors.grey[100],
        foregroundColor: const Color(0xFF01579B),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _anosDisponibles.isEmpty
          ? _buildEstadoVacio()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _anosDisponibles.length,
        itemBuilder: (context, index) {
          String ano = _anosDisponibles[index];
          return _buildCarpetaAnoTile(ano);
        },
      ),
    );
  }

  Widget _buildSelectorEmpresaHeader() {
    if (_misEmpresas.isEmpty) return const Text("Historial de Reportes");
    return DropdownButtonHideUnderline(
      child: DropdownButton<Map<String, dynamic>>(
        value: _empresaSeleccionada,
        isExpanded: true,
        style: const TextStyle(color: Color(0xFF01579B), fontWeight: FontWeight.bold, fontSize: 16),
        items: _misEmpresas.map((e) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: e,
            child: Text(e['nombre']),
          );
        }).toList(),
        onChanged: (val) {
          setState(() => _empresaSeleccionada = val);
          _descargarFacturasDeEmpresa();
        },
      ),
    );
  }

  Widget _buildCarpetaAnoTile(String ano) {
    List<String> meses = _mesesPorAno[ano] ?? [];
    meses.sort((a, b) => b.compareTo(a));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        leading: const Icon(Icons.folder, color: Colors.amber, size: 32),
        title: Text("Año $ano", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("${meses.length} meses con operaciones", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: meses.map((mes) => _buildCarpetaMesTile(ano, mes)).toList(),
      ),
    );
  }

  Widget _buildCarpetaMesTile(String ano, String mes) {
    String nombreMes = _nombresMeses[mes] ?? mes;

    return ExpansionTile(
      leading: const Icon(Icons.folder_open, color: Colors.orangeAccent),
      title: Text(nombreMes, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      children: [
        DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const TabBar(
                labelColor: Color(0xFF01579B),
                indicatorColor: Color(0xFF01579B),
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: "Formato 606"),
                  Tab(text: "Auditoría Simple"),
                ],
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                child: TabBarView(
                  children: [
                    _buildListaPorFormato(ano, mes, "606", nombreMes),
                    _buildListaPorFormato(ano, mes, "simple", nombreMes),
                  ],
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildListaPorFormato(String ano, String mes, String tipoFormato, String nombreMes) {
    final facturasFiltradas = _todasLasFacturas.where((f) =>
    f['fecha'].toString().startsWith("$ano-$mes") && f['tipo_formato'] == tipoFormato
    ).toList();

    if (facturasFiltradas.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Sin registros en este formato.", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${facturasFiltradas.length} Facturas", style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => _exportarPeriodoAExcel(ano, mes, tipoFormato),
                icon: const Icon(Icons.share, size: 14, color: Color(0xFF01579B)),
                label: const Text("Excel", style: TextStyle(fontSize: 12, color: Color(0xFF01579B))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: facturasFiltradas.length,
            itemBuilder: (context, index) {
              final f = facturasFiltradas[index];
              final double total = double.tryParse(f['monto_total'].toString()) ?? 0.0;
              return ListTile(
                dense: true,
                leading: const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFFE1F5FE),
                  child: Icon(Icons.receipt, size: 14, color: Color(0xFF01579B)),
                ),
                title: Text(f['ncf'] ?? 'Sin NCF', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: Text("RNC: ${f['rnc']} • Por: ${f['creado_por']}", style: const TextStyle(fontSize: 10)),
                trailing: Text("RD\$ ${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("Historial de Periodos Vacío", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            const Text("Las carpetas de Años y Meses se calcularán solas tan pronto proceses los primeros comprobantes con la cámara.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}