import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/screens/shop/order_detail_page.dart';
import 'package:happy/services/order_service.dart';
import 'package:intl/intl.dart';

class UserOrdersPages extends StatefulWidget {
  const UserOrdersPages({super.key});

  @override
  _UserOrdersPagesState createState() => _UserOrdersPagesState();
}

class _UserOrdersPagesState extends State<UserOrdersPages> {
  final OrderService _orderService = OrderService();
  late Future<List<Orders>> _ordersFuture;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _ordersFuture = _orderService.getUserOrders(
          user.uid); // Remplacez par l'ID de l'utilisateur actuel
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Chargez plus de commandes ici si nécessaire
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
        title: const Text('Mes commandes',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.black,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Orders>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Vous n\'avez pas encore de commandes'));
          }

          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final order = snapshot.data![index];
                return _buildOrderCard(order);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Orders order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailPage(
                orderId: order.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.id.substring(0, 8),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('dd/MM/yyyy').format(order.createdAt)}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Total: ${order.totalPrice.toStringAsFixed(2)}€',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              if (order.status == 'en préparation')
                const LinearProgressIndicator(value: 0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case 'paid':
        text = "Payé";
        color = Colors.blue;
        break;
      case 'en préparation':
        text = "En préparation";
        color = Colors.orange;
        break;
      case 'prête à être retirée':
        text = "Prête à être retirée";
        color = Colors.green;
        break;
      case 'completed':
        text = "Terminée";
        color = Colors.grey;
        break;
      default:
        text = "Default";
        color = Colors.grey;
    }

    return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: color,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18.0,
            vertical: 7,
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ));
  }
}
