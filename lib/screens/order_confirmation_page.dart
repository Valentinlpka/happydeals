// lib/screens/order_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';

import '../services/order_service.dart';

class OrderConfirmationScreen extends StatelessWidget {
  final String orderId;
  final OrderService _orderService = OrderService();

  OrderConfirmationScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmation de commande')),
      body: FutureBuilder<Orders>(
        future: _orderService.getOrder(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Commande non trouvée'));
          }

          final order = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Commande #${order.id}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text('Date: ${order.createdAt.toString()}'),
                Text('Total: ${order.totalPrice.toStringAsFixed(2)} €'),
                Text('Statut: ${order.status}'),
                const SizedBox(height: 20),
                const Text('Articles:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...order.items.map((item) => ListTile(
                      title: Text(item.name),
                      trailing: Text('${item.quantity} x ${item.price} €'),
                    )),
                const SizedBox(height: 20),
                const Text('Adresse de retrait:',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(order.pickupAddress),
                if (order.pickupCode != null) ...[
                  const SizedBox(height: 20),
                  Text('Code de retrait: ${order.pickupCode}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
