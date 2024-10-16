import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatelessWidget {
  final Orders order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

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
            Text(
                'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt)}'),
            Text('Sous-total: ${formatter.format(order.subtotal)}'),
            if (order.happyDealSavings > 0)
              Text(
                  'Économies Happy Deals: -${formatter.format(order.happyDealSavings)}',
                  style: const TextStyle(color: Colors.green)),
            if (order.discountAmount != null && order.discountAmount! > 0)
              Text(
                  'Réduction code promo: -${formatter.format(order.discountAmount)}',
                  style: const TextStyle(color: Colors.green)),
            Text('Total: ${formatter.format(order.totalPrice)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Statut: ${order.status}'),
            const SizedBox(height: 20),
            const Text('Articles:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...order.items.map((item) => ListTile(
                  title: Text(item.name),
                  subtitle: item.originalPrice != item.appliedPrice
                      ? Text(
                          '${formatter.format(item.originalPrice)} → ${formatter.format(item.appliedPrice)}',
                          style: const TextStyle(
                              decoration: TextDecoration.lineThrough))
                      : null,
                  trailing: Text(
                      '${item.quantity} x ${formatter.format(item.appliedPrice)}'),
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
