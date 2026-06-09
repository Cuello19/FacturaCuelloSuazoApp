import 'package:flutter/material.dart';
import '../../data/services/api_service.dart'; // <-- Cambiado a ruta relativa directa
import '../../data/models/factura_model.dart';  // <-- Cambiado a ruta relativa directa
import 'camera_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilexis - Historial Fiscal'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: FutureBuilder<List<FacturaModel>>(
        future: _apiService.obtenerFacturas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('❌ Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay facturas registradas en Sheets.'));
          }

          final facturas = snapshot.data!;

          return ListView.builder(
            itemCount: facturas.length,
            itemBuilder: (context, index) {
              final factura = facturas[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                  title: Text(factura.nombreSuplidor),
                  subtitle: Text('NCF: ${factura.ncf}\nFecha: ${factura.fecha}'),
                  trailing: Text(
                    'RD\$ ${factura.montoTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navegamos a la pantalla de la cámara esperando si se procesó una foto con éxito
          final resultadoExito = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraScreen()),
          );

          // Si retornó true, refrescamos el estado de la lista automáticamente
          if (resultadoExito == true) {
            setState(() {});
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}