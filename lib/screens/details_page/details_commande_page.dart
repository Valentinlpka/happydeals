// lib/screens/order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';

class OrderDetailScreen extends StatelessWidget {
  final Orders order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail de la commande')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Commande #${order.id}',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('Date: ${order.createdAt.toString()}'),
            Text('Total: ${order.totalPrice.toStringAsFixed(2)} €'),
            Text('Statut: ${order.status}'),
            const SizedBox(height: 20),
            const Text('Articles:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...order.items.map((item) => ListTile(
                  title: Text(item.name),
                  trailing: Text('${item.quantity} x ${item.price} €'),
                )),
            const SizedBox(height: 20),
            const Text('Adresse de retrait:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(order.pickupAddress),
            if (order.pickupCode != null) ...[
              const SizedBox(height: 20),
              Text('Code de retrait: ${order.pickupCode}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}
