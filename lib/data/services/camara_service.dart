import 'package:image_picker/image_picker.dart';

class CamaraService {
  final ImagePicker _picker = ImagePicker();

  /// Captura una foto utilizando la cámara del dispositivo retornando XFile (Multiplataforma).
  Future<XFile?> capturarFotoConCamara() async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85, // Balance óptimo entre legibilidad de texto y peso
      );
      return foto;
    } catch (e) {
      print("❌ Error al capturar foto desde la cámara: $e");
      return null;
    }
  }

  /// Selecciona una imagen desde la galería retornando XFile (Multiplataforma).
  Future<XFile?> seleccionarFotoDeGaleria() async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return foto;
    } catch (e) {
      print("❌ Error al seleccionar foto desde la galería: $e");
      return null;
    }
  }
}