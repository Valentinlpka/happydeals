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
  late Stream<List<Orders>> _ordersStream;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    _ordersStream =
        user != null ? _orderService.getUserOrders(user.uid) : Stream.value([]);
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
        title: const Text(
          'Mes commandes',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<Orders>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Vous n\'avez pas encore de commandes'),
            );
          }

          final orders = snapshot.data!;
          // Trier les commandes par date de création (plus récentes en premier)
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            controller: _scrollController,
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Orders order) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailPage(orderId: order.id),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commande #${order.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy à HH:mm')
                              .format(order.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    _buildStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 18,
                            color: Colors.grey[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (order.subtotal != order.totalPrice) ...[
                            Text(
                              '${order.subtotal.toStringAsFixed(2)}€',
                              style: TextStyle(
                                color: Colors.grey[600],
                                decoration: TextDecoration.lineThrough,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '${order.totalPrice.toStringAsFixed(2)}€',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (order.status == 'en préparation') ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: 0.5,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'paid':
        text = "Payée";
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        icon = Icons.payment;
        break;
      case 'en préparation':
        text = "En préparation";
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        icon = Icons.hourglass_empty;
        break;
      case 'prête à être retirée':
        text = "Prête";
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        icon = Icons.check_circle_outline;
        break;
      case 'completed':
        text = "Terminée";
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        icon = Icons.task_alt;
        break;
      default:
        text = status;
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
