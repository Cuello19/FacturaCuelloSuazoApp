import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/factura_model.dart';
import '../widgets/factura_list_item.dart';
import 'package:facturacuellosuazo_app/presentation/screens/factura_detail_screen.dart';

class HomeHistoryScreen extends StatefulWidget {
  const HomeHistoryScreen({super.key});

  @override
  State<HomeHistoryScreen> createState() => _HomeHistoryScreenState();
}

class _HomeHistoryScreenState extends State<HomeHistoryScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  late Future<List<FacturaModel>> _futureFacturas;
  bool _isRefreshing = false;
  bool _isLoading = true;
  String _empresaIdActiva = '';

  @override
  void initState() {
    super.initState();
    _inicializarHistorialEmpresa();
  }

  /// Carga de forma elástica la empresa aprobada directamente desde Supabase
  Future<void> _inicializarHistorialEmpresa() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final empresas = await _authService.obtenerMisEmpresasAprobadas(user.id);
        if (empresas.isNotEmpty) {
          _empresaIdActiva = empresas.first['id']?.toString() ?? '';
        }
      }
    } catch (e) {
      print("❌ Error cargando empresa en historial screen: $e");
    }

    if (mounted) {
      setState(() {
        _futureFacturas = _apiService.obtenerFacturas(_empresaIdActiva);
        _isLoading = false;
      });
    }
  }

  void _loadData() {
    setState(() {
      _futureFacturas = _apiService.obtenerFacturas(_empresaIdActiva);
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    _loadData();
    await _futureFacturas;
    if (mounted) setState(() => _isRefreshing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🎉 Historial actualizado desde PostgreSQL')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoNCF - Historial Fiscal'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          _isRefreshing
              ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
              : IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<FacturaModel>>(
          future: _futureFacturas,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("❌ Error cargando datos: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("📂 No hay facturas registradas en esta empresa."));
            }

            final facturas = snapshot.data!;
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: facturas.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final factura = facturas[index];
                final bool es606 = factura.tipoFormato == '606';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: es606 ? Colors.blue[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: es606 ? Colors.blue : Colors.orange, width: 0.8),
                          ),
                          child: Text(
                            es606 ? "📄 606" : "🔍 Auditoría",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: es606 ? Colors.blue[900] : Colors.orange[900]
                            ),
                          ),
                        ),
                      ),
                    ),
                    FacturaListItem(
                      factura: factura,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FacturaDetailScreen(factura: factura),
                          ),
                        ).then((value) {
                          if (value == true) _onRefresh();
                        });
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}