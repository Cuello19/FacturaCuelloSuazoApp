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
  final double montoServicios;
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
  final String fileUrl;

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
    required this.montoServicios,
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
    required this.fileUrl,
  });

  // 💡 GETTER DINÁMICO MEJORADO: Ideal para la columna del día en tu Excel de la DGII
  String get dia {
    final fechaLimpia = fecha.replaceAll('-', '').trim();
    // Si es un formato Simple completo (YYYYMMDD) extrae los últimos 2 caracteres
    if (fechaLimpia.length >= 8) {
      return fechaLimpia.substring(6, 8);
    }
    // Si es formato 606 (YYYYMM), por defecto usa el día de corte o '01'
    return '01';
  }

  double get subtotal => montoTotal - itbisTotal;

factory FacturaModel.fromJson(Map<String, dynamic> json) {
final fmt = (json['tipo_formato'] ?? json['tipoFormato'] ?? '606')
.toString()
.toLowerCase()
.trim();

return FacturaModel(
id: json['id']?.toString() ?? '',
empresaId: json['empresa_id']?.toString() ?? '',
tipoFormato: fmt,
rnc: json['rnc']?.toString() ?? '',
tipoId: json['tipo_id']?.toString() ?? '1',
nombreEmpresa: json['nombre_empresa']?.toString() ?? 'N/A',
tipoGasto: json['tipo_gasto']?.toString() ?? '02 - GASTOS POR TRABAJOS, SUMINISTROS Y SERVICIOS',
ncf: json['ncf']?.toString() ?? 'N/A',
documentoModificado: json['documento_modificado']?.toString() ?? '',
fecha: json['fecha']?.toString() ?? '',
fechaPago: json['fecha_pago']?.toString() ?? '',

// 🚀 BLINDAJE ULTRA SEGURO CONTRA NULOS DE POSTGRESQL:
montoServicios: (json['monto_servicios'] as num?)?.toDouble() ?? 0.0,
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
fileUrl: json['file_url']?.toString() ?? '',
);
}}