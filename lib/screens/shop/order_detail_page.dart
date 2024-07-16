import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/services/order_service.dart';
import 'package:intl/intl.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  _OrderDetailPageState createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final OrderService _orderService = OrderService();
  late Future<Orders> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = _orderService.getOrder(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la commande',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<Orders>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Commande non trouvée'));
          }

          final order = snapshot.data!;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderHeader(order),
                  const SizedBox(height: 24),
                  _buildOrderStatus(order),
                  const SizedBox(height: 24),
                  _buildOrderItems(order),
                  const SizedBox(height: 24),
                  _buildOrderSummary(order),
                  const SizedBox(height: 24),
                  _buildPickupInfo(order),
                  const SizedBox(height: 24),
                  _buildActionButton(order),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderHeader(Orders order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commande #${order.id.substring(0, 8)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Passée le ${DateFormat('dd MMMM yyyy à HH:mm').format(order.createdAt)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatus(Orders order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statut de la commande',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(_getStatusIcon(order.status),
                    color: _getStatusColor(order.status)),
                const SizedBox(width: 8),
                Text(
                  order.status,
                  style: TextStyle(
                      color: _getStatusColor(order.status),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (order.status == 'en préparation') ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(value: 0.5),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(Orders order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Articles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                            child:
                                Text('Image')), // Remplacer par une vraie image
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text('Quantité: ${item.quantity}'),
                            Text(
                                '${(item.price * item.quantity).toStringAsFixed(2)}€'),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(Orders order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Récapitulatif',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sous-total'),
                Text('${order.totalPrice.toStringAsFixed(2)}€'),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Frais de livraison'),
                Text('0.00€'),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${order.totalPrice.toStringAsFixed(2)}€',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupInfo(Orders order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations de retrait',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Adresse: ${order.pickupAddress}'),
            if (order.pickupCode != null) ...[
              const SizedBox(height: 4),
              Text('Code de retrait: ${order.pickupCode}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Orders order) {
    if (order.status == 'prête à être retirée') {
      return ElevatedButton(
        onPressed: () => _showPickupConfirmation(order),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          minimumSize: const Size(double.infinity, 50),
        ),
        child: const Text('Confirmer le retrait'),
      );
    }
    return const SizedBox.shrink();
  }

  void _showPickupConfirmation(Orders order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String enteredCode = '';
        return AlertDialog(
          title: const Text('Confirmer le retrait'),
          content: TextField(
            onChanged: (value) => enteredCode = value,
            decoration:
                const InputDecoration(labelText: 'Entrez le code de retrait'),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Confirmer'),
              onPressed: () async {
                if (enteredCode == order.pickupCode) {
                  await _orderService.confirmOrderPickup(order.id, enteredCode);
                  Navigator.of(context).pop();
                  setState(() {
                    _orderFuture = _orderService.getOrder(widget.orderId);
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code de retrait incorrect')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'payée':
        return Icons.payment;
      case 'en préparation':
        return Icons.inventory;
      case 'prête à être retirée':
        return Icons.store;
      case 'terminée':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'payée':
        return Colors.blue;
      case 'en préparation':
        return Colors.orange;
      case 'prête à être retirée':
        return Colors.green;
      case 'terminée':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
