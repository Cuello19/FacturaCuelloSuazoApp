import 'package:flutter/material.dart';
import '../../data/models/factura_model.dart';

class FacturaListItem extends StatelessWidget {
  final FacturaModel factura;
  final VoidCallback onTap;

  const FacturaListItem({
    super.key,
    required this.factura,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factura.rnc.isNotEmpty ? "RNC Suplidor: ${factura.rnc}" : "Establecimiento Comercial",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "NCF: ${factura.ncf}",
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                    Text(
                      "Fecha: ${factura.fecha.split(' ')[0]}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "RD\$ ${factura.montoTotal.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20,)
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}