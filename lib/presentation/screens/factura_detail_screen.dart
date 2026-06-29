import 'package:flutter/material.dart';
import '../../data/models/factura_model.dart';

class FacturaDetailScreen extends StatelessWidget {
  final FacturaModel factura;
  const FacturaDetailScreen({super.key, required this.factura});

  String _obtenerUrlImagenIncrustada(String fileUrl) {
    if (fileUrl.isEmpty) return '';
    final regExp = RegExp(r'/d/([a-zA-Z0-9-_]+)');
    final match = regExp.firstMatch(fileUrl);
    if (match != null && match.groupCount >= 1) {
      final idArchivo = match.group(1);
      return 'https://docs.google.com/uc?export=view&id=$idArchivo';
    }
    return fileUrl;
  }

  String _formatearFechaLimpia(String periodo, String dia) {
    if (periodo.length == 6) {
      return "$dia/${periodo.substring(4, 6)}/${periodo.substring(0, 4)}";
    }
    return "$dia/$periodo";
  }

  @override
  Widget build(BuildContext context) {
    final String urlFinalImagen = _obtenerUrlImagenIncrustada(factura.fileUrl);
    final bool es606 = factura.tipoFormato == '606';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Auditoría'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta 1: Datos Emisor
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Comprobante Fiscal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: es606 ? Colors.blue[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(es606 ? "📄 606" : "🔍 Simple", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: es606 ? Colors.blue[900] : Colors.orange[900])),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildFilaDato(Icons.badge, 'RNC Suplidor:', factura.rnc),
                    _buildFilaDato(Icons.fingerprint, 'NCF:', factura.ncf),
                    _buildFilaDato(Icons.calendar_month, 'Fecha Emisión:', _formatearFechaLimpia(factura.fecha, factura.dia)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tarjeta 2: Distribución Financiera
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Valores y Desglose', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
                    const Divider(height: 20),
                    _buildFilaDato(Icons.attach_money, 'Monto Subtotal:', 'RD\$ ${factura.subtotal.toStringAsFixed(2)}'),
                    _buildFilaDato(Icons.percent, 'ITBIS Facturado:', 'RD\$ ${factura.itbisTotal.toStringAsFixed(2)}'),
                    if (es606) ...[
                      _buildFilaDato(Icons.room_service, 'Monto Servicios:', 'RD\$ ${factura.montoServicios.toStringAsFixed(2)}'),
                      _buildFilaDato(Icons.category, 'Monto Bienes:', 'RD\$ ${factura.montoBienes.toStringAsFixed(2)}'),
                    ],
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monto Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('RD\$ ${factura.montoTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tarjeta 3: Trazabilidad Operador
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trazabilidad de Auditoría', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
                    const Divider(height: 20),
                    _buildFilaDato(Icons.credit_card, 'Forma de Pago:', factura.formaPago),
                    _buildFilaDato(Icons.person, 'Procesado Por:', factura.creadoPor),
                    _buildFilaDato(Icons.gpp_good, 'Estatus Interno:', factura.estatus),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🖼️ VISUALIZADOR DE LA FACTURA REAL AL FINAL DE TODO EL LISTADO CARD
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 12),
              child: Text('Evidencia Física del Comprobante', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ),
            urlFinalImagen.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text("No hay imagen física asociada a este registro.", style: TextStyle(color: Colors.grey, fontSize: 13))))
                : Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 450),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
                color: Colors.black54,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                urlFinalImagen,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Colors.white)));
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 40, color: Colors.white70),
                          SizedBox(height: 8),
                          Text('Error al cargar evidencia física de Drive', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFilaDato(IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Text(etiqueta, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(child: Text(valor, style: const TextStyle(color: Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }
}