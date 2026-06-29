class FacturaModel {
  final String id;
  final String empresaId;
  final String tipoFormato;
  final String rnc;
  final String tipoId;
  final String nombreEmpresa;
  final String tipoGasto;
  final String ncf;
  final String documentoModificado;
  final String fecha;
  final String fechaPago;
  final double montoServicios; // 🚀 CORREGIDO: De montoServices a montoServicios
  final double montoBienes;
  final double montoTotal;
  final double itbisTotal;
  final double itbisRetenid;
  final double itbisProporcional;
  final double itbisCosto;
  final double itbisAdelantar;
  final double itbisPercibido;
  final String tipoRetencionIsr;
  final double retencionRenta;
  final double isrPercibido;
  final double isc;
  final double otrosImpuestos;
  final double montoLey;
  final String formaPago;
  final String estatus;
  final String creadoPor;

  FacturaModel({
    required this.id,
    required this.empresaId,
    required this.tipoFormato,
    required this.rnc,
    required this.tipoId,
    required this.nombreEmpresa,
    required this.tipoGasto,
    required this.ncf,
    required this.documentoModificado,
    required this.fecha,
    required this.fechaPago,
    required this.montoServicios, // 🚀 CORREGIDO
    required this.montoBienes,
    required this.montoTotal,
    required this.itbisTotal,
    required this.itbisRetenid,
    required this.itbisProporcional,
    required this.itbisCosto,
    required this.itbisAdelantar,
    required this.itbisPercibido,
    required this.tipoRetencionIsr,
    required this.retencionRenta,
    required this.isrPercibido,
    required this.isc,
    required this.otrosImpuestos,
    required this.montoLey,
    required this.formaPago,
    required this.estatus,
    required this.creadoPor,
  });

  // 💡 GETTERS DE COMPATIBILIDAD EXTERNA PARA RESPALDAR FACTURA_DETAIL_SCREEN
  String get fileUrl => '';
  String get dia => fecha.length >= 8 ? fecha.substring(6, 8) : '01';
  double get subtotal => montoTotal - itbisTotal;

  factory FacturaModel.fromJson(Map<String, dynamic> json) {
    return FacturaModel(
      id: json['id']?.toString() ?? '',
      empresaId: json['empresa_id']?.toString() ?? '',
      tipoFormato: json['tipo_formato']?.toString() ?? '606',
      rnc: json['rnc']?.toString() ?? '',
      tipoId: json['tipo_id']?.toString() ?? '1',
      nombreEmpresa: json['nombre_empresa']?.toString() ?? 'N/A',
      tipoGasto: json['tipo_gasto']?.toString() ?? '02 - GASTOS POR TRABAJOS, SUMINISTROS Y SERVICIOS',
      ncf: json['ncf']?.toString() ?? 'N/A',
      documentoModificado: json['documento_modificado']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
      fechaPago: json['fecha_pago']?.toString() ?? '',
      montoServicios: (json['monto_servicios'] as num?)?.toDouble() ?? 0.0, // 🚀 CORREGIDO
      montoBienes: (json['monto_bienes'] as num?)?.toDouble() ?? 0.0,
      montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0.0,
      itbisTotal: (json['itbis_total'] as num?)?.toDouble() ?? 0.0,
      itbisRetenid: (json['itbis_retenid'] as num?)?.toDouble() ?? 0.0,
      itbisProporcional: (json['itbis_proporcional'] as num?)?.toDouble() ?? 0.0,
      itbisCosto: (json['itbis_costo'] as num?)?.toDouble() ?? 0.0,
      itbisAdelantar: (json['itbis_adelantar'] as num?)?.toDouble() ?? 0.0,
      itbisPercibido: (json['itbis_percibido'] as num?)?.toDouble() ?? 0.0,
      tipoRetencionIsr: json['tipo_retencion_isr']?.toString() ?? '',
      retencionRenta: (json['retencion_renta'] as num?)?.toDouble() ?? 0.0,
      isrPercibido: (json['isr_percibido'] as num?)?.toDouble() ?? 0.0,
      isc: (json['isc'] as num?)?.toDouble() ?? 0.0,
      otrosImpuestos: (json['otros_impuestos'] as num?)?.toDouble() ?? 0.0,
      montoLey: (json['monto_ley'] as num?)?.toDouble() ?? 0.0,
      formaPago: json['forma_pago']?.toString() ?? '03 - TARJETA CRÉDITO/DÉBITO',
      estatus: json['estatus']?.toString() ?? 'VÁLIDO',
      creadoPor: json['creado_por']?.toString() ?? 'Sistema',
    );
  }
}