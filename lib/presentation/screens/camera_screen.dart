import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/api_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imageFile;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  /// Abre la cámara nativa del teléfono para tomar la foto del ticket
  Future<void> _tomarFoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Optimiza el peso para evitar desbordes en Apps Script
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
      }
    } catch (e) {
      _mostrarAlerta("Error al abrir la cámara: $e");
    }
  }

  /// Procesa la subida y extracción fiscal a la nube
  Future<void> _subirFactura() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
    });

    final resultado = await _apiService.subirFactura(_imageFile!);

    setState(() {
      _isLoading = false;
    });

    if (resultado['success'] == true) {
      // Si se extrajo nítido, volvemos al home avisando el éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 ¡Factura procesada y guardada en Sheets!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Retornamos true para refrescar la lista
      }
    } else {
      _mostrarAlerta(resultado['error'] ?? 'Error desconocido al procesar');
    }
  }

  void _mostrarAlerta(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aviso del Sistema'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Comprobante'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text(
              'Enviando factura a Gemini API...',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Text(
                'Esto puede tardar de 5 a 8 segundos mientras se analizan los datos fiscales de la DGII.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      )
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Contenedor de la vista previa de la foto
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  )
                      : const Center(
                    child: Text(
                      'Ninguna imagen capturada',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Botón para disparar la cámara
              ElevatedButton.icon(
                onPressed: _tomarFoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tomar Foto de Factura'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              // Botón para procesar la subida (Solo se activa si hay foto)
              if (_imageFile != null)
                ElevatedButton.icon(
                  onPressed: _subirFactura,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Procesar Datos Fiscales'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}