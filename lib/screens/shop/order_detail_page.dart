import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/services/order_service.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';

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
      bottomNavigationBar: FutureBuilder<Orders>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return _buildBottomBar(snapshot.data!);
          }
          return const SizedBox.shrink();
        },
      ),
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
                  _buildPickupCode(order),
                  const SizedBox(height: 24),
                  _buildPickupInfo(order),
                  const SizedBox(height: 24),
                  _buildOrderItems(order),
                  const SizedBox(height: 24),
                  _buildOrderSummary(order),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(Orders order) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(
          width: 0.4,
          color: Colors.black26,
        ))),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.blue[800]),
              ),
              onPressed: () async {
                await MapsLauncher.launchQuery(order.pickupAddress);
              },
              child: const Text("S'y rendre"),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader(Orders order) {
    return Padding(
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
            'Passée le ${DateFormat('dd/MM/yyyy à HH:mm').format(order.createdAt)}',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatus(Orders order) {
    return Padding(
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
                _getStatusText(order.status),
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
    );
  }

  Widget _buildOrderItems(Orders order) {
    return Padding(
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        color:
                            item.image != '' ? Colors.white : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: item.image != ''
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CachedNetworkImage(imageUrl: item.image),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildOrderSummary(Orders order) {
    return Padding(
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
    );
  }

  Widget _buildPickupInfo(Orders order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations de retrait',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Adresse: ${order.pickupAddress}'),
        ],
      ),
    );
  }

  Widget _buildPickupCode(Orders order) {
    return order.pickupCode != null
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Code de retrait',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  '${order.pickupCode}',
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 5,
                  ),
                ),
              ],
            ),
          )
        : const SizedBox();
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

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return "Payé";

      case 'en préparation':
        return "En préparation";
      case 'prête à être retirée':
        return "Prête à être retirée";
      case 'terminée':
        return "Terminée";
      default:
        return "Default";
    }
  }
}
