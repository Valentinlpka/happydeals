import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/models/restaurant_order.dart';
import 'package:happy/screens/restaurant_order_detail_page.dart';
import 'package:happy/services/restaurant_order_service.dart';
import 'package:intl/intl.dart';

class UserRestaurantOrdersPage extends StatefulWidget {
  const UserRestaurantOrdersPage({super.key});

  @override
  State<UserRestaurantOrdersPage> createState() => _UserRestaurantOrdersPageState();
}

class _UserRestaurantOrdersPageState extends State<UserRestaurantOrdersPage> {
  final RestaurantOrderService _orderService = RestaurantOrderService();
  late Stream<List<RestaurantOrder>> _ordersStream;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    _ordersStream = user != null 
        ? _orderService.getUserRestaurantOrders(user.uid) 
        : Stream.value([]);
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
        title: Text(
          'Mes commandes restaurant',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<RestaurantOrder>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print('Erreur lors de la récupération des commandes: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64.sp,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Une erreur est survenue',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Impossible de charger vos commandes',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 64.sp,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Aucune commande restaurant',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Vous n\'avez pas encore passé de commande dans un restaurant',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data!;
          // Les commandes sont déjà triées par date dans le service

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
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

  Widget _buildOrderCard(RestaurantOrder order) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Colors.grey.withAlpha(26),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantOrderDetailPage(
                  orderId: order.id,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec logo du restaurant
                Row(
                  children: [
                    // Logo du restaurant
                    Container(
                      width: 48.w,
                      height: 48.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: order.restaurantLogo.isNotEmpty
                            ? Image.network(
                                order.restaurantLogo,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                    Icon(
                                      Icons.restaurant,
                                      size: 24.sp,
                                      color: Colors.grey[400],
                                    ),
                              )
                            : Icon(
                                Icons.restaurant,
                                size: 24.sp,
                                color: Colors.grey[400],
                              ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.restaurantName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Commande #${order.id.substring(0, 8)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(order.status),
                  ],
                ),
                
                SizedBox(height: 16.h),
                
                // Informations de la commande
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 18.sp,
                                color: Colors.grey[700],
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14.sp,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy à HH:mm')
                                .format(order.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 8.h),
                      
                      // Détails des frais
                      if (order.deliveryFee != null || order.serviceFee != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sous-total',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13.sp,
                              ),
                            ),
                            Text(
                              '${order.subtotal.toStringAsFixed(2)}€',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                        if (order.deliveryFee != null) ...[
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Livraison',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13.sp,
                                ),
                              ),
                              Text(
                                '${order.deliveryFee!.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (order.serviceFee != null) ...[
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Service',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13.sp,
                                ),
                              ),
                              Text(
                                '${order.serviceFee!.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (order.discountAmount != null && order.discountAmount! > 0) ...[
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Réduction',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontSize: 13.sp,
                                ),
                              ),
                              Text(
                                '-${order.discountAmount!.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.green[600],
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: 8.h),
                        Divider(height: 1.h, color: Colors.grey[300]),
                        SizedBox(height: 8.h),
                      ],
                      
                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${order.amount.toStringAsFixed(2)}€',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Barre de progression pour les commandes en cours
                if (order.isActive) ...[
                  SizedBox(height: 16.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: _getProgressValue(order.status),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStatusColor(order.status),
                      ),
                      minHeight: 4.h,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _getStatusDescription(order.status),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
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
      case 'pending':
        text = "En attente";
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        icon = Icons.schedule;
        break;
      case 'confirmed':
        text = "Confirmée";
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        icon = Icons.check_circle_outline;
        break;
      case 'preparing':
        text = "En préparation";
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        icon = Icons.restaurant;
        break;
      case 'ready':
        text = "Prête";
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        icon = Icons.check_circle;
        break;
      case 'delivering':
        text = "En livraison";
        backgroundColor = Colors.purple[50]!;
        textColor = Colors.purple[700]!;
        icon = Icons.delivery_dining;
        break;
      case 'delivered':
        text = "Livrée";
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        icon = Icons.task_alt;
        break;
      case 'cancelled':
        text = "Annulée";
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        icon = Icons.cancel_outlined;
        break;
      default:
        text = status;
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        icon = Icons.info_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14.sp,
            color: textColor,
          ),
          SizedBox(width: 6.w),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  double _getProgressValue(String status) {
    switch (status) {
      case 'pending':
        return 0.1;
      case 'confirmed':
        return 0.3;
      case 'preparing':
        return 0.6;
      case 'ready':
        return 0.8;
      case 'delivering':
        return 0.9;
      case 'delivered':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'delivering':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'Votre commande est en attente de confirmation';
      case 'confirmed':
        return 'Votre commande a été confirmée par le restaurant';
      case 'preparing':
        return 'Votre commande est en cours de préparation';
      case 'ready':
        return 'Votre commande est prête pour la livraison';
      case 'delivering':
        return 'Votre commande est en cours de livraison';
      case 'delivered':
        return 'Votre commande a été livrée';
      default:
        return 'Statut de commande inconnu';
    }
  }
} 