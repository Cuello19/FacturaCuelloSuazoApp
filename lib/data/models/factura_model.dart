class FacturaModel {
  final int idRegistro;
  final String fecha;
  final String rnc;
  final String nombreSuplidor;
  final String ncf;
  final double subtotal;
  final double itbis16;
  final double itbis18;
  final double itbisTotal;
  final double montoLey;
  final double montoTotal;
  final String fileUrl;

  FacturaModel({
    required this.idRegistro,
    required this.fecha,
    required this.rnc,
    required this.nombreSuplidor,
    required this.ncf,
    required this.subtotal,
    required this.itbis16,
    required this.itbis18,
    required this.itbisTotal,
    required this.montoLey,
    required this.montoTotal,
    required this.fileUrl,
  });

  // Constructor Factory para mapear el JSON directo de la base de datos de tu Sheets
  factory FacturaModel.fromJson(Map<String, dynamic> json) {
    return FacturaModel(
      idRegistro: json['id_registro'] ?? 0,
      fecha: json['fecha'] ?? '',
      rnc: json['rnc'] ?? '000000000',
      nombreSuplidor: json['nombre_suplidor'] ?? 'Comercio Desconocido',
      ncf: json['ncf'] ?? 'N/A',
      subtotal: (json['subtotal'] as num).toDouble(),
      itbis16: (json['itbis_16'] as num).toDouble(),
      itbis18: (json['itbis_18'] as num).toDouble(),
      itbisTotal: (json['itbis_total'] as num).toDouble(),
      montoLey: (json['monto_ley'] as num).toDouble(),
      montoTotal: (json['monto_total'] as num).toDouble(),
      fileUrl: json['file_url'] ?? '',
    );
  }
}