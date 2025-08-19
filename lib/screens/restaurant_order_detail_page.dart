import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/models/restaurant_order.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class RestaurantOrderDetailPage extends StatefulWidget {
  final String orderId;

  const RestaurantOrderDetailPage({
    super.key,
    required this.orderId,
  });

  @override
  State<RestaurantOrderDetailPage> createState() => _RestaurantOrderDetailPageState();
}

class _RestaurantOrderDetailPageState extends State<RestaurantOrderDetailPage> {
  RestaurantOrder? order;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      
      if (doc.exists) {
        setState(() {
          order = RestaurantOrder.fromFirestore(doc);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Commande introuvable';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Erreur lors du chargement: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            SliverFillRemaining(
              child: _buildErrorView(),
            )
          else if (order != null) ...[
            SliverToBoxAdapter(child: _buildOrderHeader()),
            SliverToBoxAdapter(child: _buildOrderStatus()),
            SliverToBoxAdapter(child: SizedBox(height: 16.h)),
            SliverToBoxAdapter(child: _buildRestaurantInfo()),
            SliverToBoxAdapter(child: SizedBox(height: 16.h)),
            SliverToBoxAdapter(child: _buildOrderItems()),
            SliverToBoxAdapter(child: SizedBox(height: 16.h)),
            SliverToBoxAdapter(child: _buildOrderSummary()),
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ],
      ),
      bottomNavigationBar: order != null && order!.isActive ? _buildBottomActions() : null,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20.sp),
        onPressed: () {
          // Vérifier si on peut revenir en arrière, sinon aller à l'accueil
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.of(context).pushReplacementNamed('/home');
          }
        },
      ),
      title: Text(
        'Détails de la commande',
        style: TextStyle(
          color: Colors.black87,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.home, color: Colors.black87, size: 20.sp),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
          tooltip: 'Retour à l\'accueil',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: Colors.grey[200],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.sp,
            color: Colors.red[400],
          ),
          SizedBox(height: 16.h),
          Text(
            error!,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
                error = null;
              });
              _loadOrder();
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: _getStatusColor(order!.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              order!.statusText,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(order!.status),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Commande #${order!.id.substring(0, 8)}',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            DateFormat('dd/MM/yyyy à HH:mm').format(order!.createdAt),
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
         
          if (order!.pickupTime != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16.sp,
                    color: Colors.green[600],
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Heure de retrait estimée: ${order!.pickupTime}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Code de retrait (affiché uniquement quand la commande est prête)
          if (order!.pickupCode != null && order!.status == 'prête à être retirée') ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[400]!, Colors.purple[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 8.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          Icons.qr_code,
                          size: 24.sp,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Code de retrait',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            Text(
                              'Présentez ce code au commerçant',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      children: [
                        Text(
                          order!.pickupCode!,
                          style: TextStyle(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                            letterSpacing: 4.w,
                            fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: order!.pickupCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Code copié dans le presse-papier'),
                                backgroundColor: Colors.green[600],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy,
                                  size: 14.sp,
                                  color: Colors.purple[600],
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  'Copier le code',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.purple[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderStatus() {
    final statusSteps = [
      {'key': 'preparing', 'label': 'Préparation', 'icon': Icons.restaurant},
      {'key': 'prête à être retirée', 'label': 'Prête à retirer', 'icon': Icons.inventory_2},
      {'key': 'completed', 'label': 'Terminée', 'icon': Icons.done_all},
    ];

    // Si le statut est 'confirmed', on l'affiche comme 'preparing' (première étape)
    // Si le statut est 'delivered', on l'affiche comme 'completed'
    String displayStatus = order!.status;
    if (displayStatus == 'confirmed') {
      displayStatus = 'preparing';
    } else if (displayStatus == 'delivered') {
      displayStatus = 'completed';
    }
    
    final currentIndex = statusSteps.indexWhere((step) => step['key'] == displayStatus);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suivi de commande',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: statusSteps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isActive = index <= currentIndex;
              final isCurrent = index == currentIndex;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        color: isActive ? Theme.of(context).primaryColor : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        step['icon'] as IconData,
                        color: isActive ? Colors.white : Colors.grey[400],
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      step['label'] as String,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? Colors.black87 : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (index < statusSteps.length - 1) ...[
                      SizedBox(height: 8.h),
                      Container(
                        height: 2.h,
                        color: isActive ? Theme.of(context).primaryColor : Colors.grey[200],
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4.r,
                  offset: Offset(0, 1.h),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: order!.restaurantLogo.isNotEmpty
                  ? Image.network(
                      order!.restaurantLogo,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildDefaultLogo(),
                    )
                  : _buildDefaultLogo(),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order!.restaurantName,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14.sp,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        order!.restaurantAddress,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (order!.distance != null) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 14.sp,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${order!.distance!.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Container(
      color: Colors.grey[100],
      child: Icon(
        Icons.restaurant,
        size: 30.sp,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildOrderItems() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Articles commandés',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16.h),
          ...order!.items.map((item) => _buildOrderItem(item)),
        ],
      ),
    );
  }

  Widget _buildOrderItem(RestaurantOrderItem item) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[100]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6.w,
            height: 6.h,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${item.totalPrice.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      'Quantité: ${item.quantity}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Text(
                      '${item.unitPrice.toStringAsFixed(2)} € / unité',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (item.variants != null && item.variants!.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personnalisation:',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        ...item.variants!.map((variant) => Text(
                          '• ${variant.toString()}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Récapitulatif',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16.h),
          _buildSummaryRow('Sous-total', '${order!.subtotal.toStringAsFixed(2)} €'),
          if (order!.deliveryFee != null)
            _buildSummaryRow('Frais de livraison', '${order!.deliveryFee!.toStringAsFixed(2)} €'),
          if (order!.serviceFee != null)
            _buildSummaryRow('Frais de service', '${order!.serviceFee!.toStringAsFixed(2)} €'),
          if (order!.discountAmount != null && order!.discountAmount! > 0) ...[
            _buildSummaryRow(
              'Réduction${order!.promoCode != null ? " (${order!.promoCode})" : ""}',
              '-${order!.discountAmount!.toStringAsFixed(2)} €',
              color: Colors.green,
            ),
          ],
          Divider(height: 24.h, color: Colors.grey[300]),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total payé',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${order!.amount.toStringAsFixed(2)} €',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: color ?? Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 25.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10.r,
            offset: Offset(0, -2.h),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _navigateToRestaurant(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
          icon: Icon(
            Icons.directions,
            color: Colors.white,
            size: 20.sp,
          ),
          label: Text(
            'Se rendre chez le commerçant',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.orange; // Même couleur que preparing car c'est affiché comme tel
      case 'preparing':
        return Colors.orange;
      case 'prête à être retirée':
        return Colors.purple;
      case 'delivering':
        return Colors.purple; // Click & collect - même couleur que ready
      case 'completed':
        return Colors.green; // Terminée
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _navigateToRestaurant() async {
    try {
      // Créer l'URL Google Maps avec l'adresse du restaurant
      final address = Uri.encodeComponent(order!.restaurantAddress);
      final url = 'https://www.google.com/maps/dir/?api=1&destination=$address';
      
      // Importer url_launcher
      final uri = Uri.parse(url);
      
      // Vérifier si on peut lancer l'URL
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: afficher l'adresse dans une dialog
        _showAddressDialog();
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'ouverture de Maps: $e');
      _showAddressDialog();
    }
  }

  void _showAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.location_on,
              color: Theme.of(context).primaryColor,
              size: 24.sp,
            ),
            SizedBox(width: 8.w),
            const Text('Adresse du restaurant'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order!.restaurantName,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              order!.restaurantAddress,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.black87,
              ),
            ),
            if (order!.pickupTime != null) ...[
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16.sp,
                      color: Colors.green[600],
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Retrait estimé: ${order!.pickupTime}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Code de retrait dans la dialog
            if (order!.pickupCode != null && order!.status == 'prête à être retirée') ...[
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code,
                          size: 16.sp,
                          color: Colors.purple[600],
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Code de retrait: ${order!.pickupCode}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple[700],
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Présentez ce code au commerçant',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.purple[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Copier l'adresse dans le presse-papier
              Clipboard.setData(ClipboardData(text: order!.restaurantAddress));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adresse copiée dans le presse-papier'),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
          ),
        ],
      ),
    );
  }
}