import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../data/models/factura_model.dart';

class ApiService {
  /// 📥 GET: Obtiene el historial completo de facturas desde Google Sheets
  Future<List<FacturaModel>> obtenerFacturas() async {
    try {
      final response = await http.get(Uri.parse(AppConstants.apiEndpoint));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true && jsonResponse['facturas'] != null) {
          final List<dynamic> listaFacturasJson = jsonResponse['facturas'];
          return listaFacturasJson.map((json) => FacturaModel.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print("❌ Error en ApiService GET: $e");
      return [];
    }
  }

  /// 📤 POST: Envía la imagen física en Base64 hacia el Google Apps Script
  Future<Map<String, dynamic>> subirFactura(File imagen) async {
    try {
      List<int> imageBytes = await imagen.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      String mimeType = imagen.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      final Map<String, String> payload = {
        "image_base64": base64Image,
        "mime_type": mimeType
      };

      final response = await http.post(
        Uri.parse(AppConstants.apiEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          "success": false,
          "error": "Error en el servidor de Google. Código: ${response.statusCode}"
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": "No se pudo conectar con el backend: $e"
      };
    }
  }
}