import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../data/models/factura_model.dart';

class ApiService {
  final _supabase = Supabase.instance.client;

  /// 🌍 ENRUTADOR GLOBAL PÚBLICO
  /// Con esto, no importa la IP, ni la red, ni el país. Todos los celulares apuntan a Render en producción.
  static String get _backendUrl {
    if (kIsWeb) {
      // En la web de desarrollo apunta local, pero para tus usuarios finales de la app...
      return 'http://localhost:3000/api/procesar-factura';
    }

    // 🚀 UNIFICADO PARA CELULARES: Apunta directo a tu URL pública en la nube de Render
    return 'https://autoncf-backend.onrender.com/api/procesar-factura';
  }

  /// 📥 Obtiene el historial de facturas directo desde Supabase PostgreSQL filtrado por empresa
  Future<List<FacturaModel>> obtenerFacturas(String empresaId) async {
    try {
      final response = await _supabase
          .from('facturas')
          .select('*')
          .eq('empresa_id', empresaId)
          .order('fecha', ascending: false);

      final List<dynamic> listaData = response as List<dynamic>;
      return listaData.map((json) => FacturaModel.fromJson(json)).toList();
    } catch (e) {
      print("❌ Error en ApiService de Supabase: $e");
      return [];
    }
  }

  /// 🚀 MULTIPART POST: Envía los bytes de la factura física directo al backend dinámico
  Future<bool> enviarFacturaAlBackend({
    required XFile imagen,
    required String empresaId,
    required String tipoFormato,
    required String creadoPor,
  }) async {
    try {
      final String urlDestino = _backendUrl;
      print("📡 Conectando de forma global con el motor de AutoNCF en: $urlDestino");

      final url = Uri.parse(urlDestino);
      final request = http.MultipartRequest('POST', url);

      // 📄 Inyección de campos de texto requeridos por el controlador de Express
      request.fields['empresa_id'] = empresaId;
      request.fields['tipoFormato'] = tipoFormato; // ⚡ Sincroniza dinámicamente si es 606 o simple
      request.fields['creado_por'] = creadoPor;

      // 📸 Lectura de bytes binarios (100% compatible con Web, Netlify, Android e iOS)
      final bytesImagen = await imagen.readAsBytes();

      String mimeType = 'image/jpeg'; // Por defecto
      final String nombreMinuscula = imagen.name.toLowerCase();

      if (nombreMinuscula.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (nombreMinuscula.endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'imagen',
        bytesImagen,
        filename: imagen.name,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      // Despachamos la petición por la red
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ Comprobante auditado e indexado de forma nativa por el backend.");
        return true;
      } else {
        print("❌ Fallo en respuesta del backend. Código: ${response.statusCode} - Body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("💥 Error crítico de conectividad en ApiService POST: $e");
      return false;
    }
  }
}