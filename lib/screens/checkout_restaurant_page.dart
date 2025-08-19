import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/restaurant.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/restaurant/user_restaurant_orders_page.dart';
import 'package:happy/services/cart_restaurant_service.dart';
import 'package:happy/widgets/cart_item_widget.dart';
import 'package:happy/widgets/customer_message_widget.dart';
import 'package:happy/widgets/delivery_time_selector.dart';
import 'package:happy/widgets/unified_payment_button.dart';
import 'package:provider/provider.dart';

class CheckoutPage extends StatefulWidget {
  final RestaurantCart cart;

  const CheckoutPage({
    super.key,
    required this.cart,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Restaurant? restaurant;
  double? distanceInKm;
  bool isLoadingRestaurant = true;
  bool isCalculatingDistance = true;
  
  // Contrôleurs pour les champs
  final TextEditingController _promoCodeController = TextEditingController();
  String? appliedPromoCode;
  double promoDiscount = 0.0;
  bool isApplyingPromo = false;
  
  // Frais et totaux
  double deliveryFee = 2.50;
  double serviceFee = 1.50;
  
  // Variables pour le paiement
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _orderId;

  // Nouvelles variables pour la gestion des commandes
  String _customerMessage = '';
  DateTime? _scheduledTime;
  String _deliveryType = 'asap';
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _generateOrderId();
    await _loadRestaurantInfo();
    await _calculateDistance();
  }

  Future<void> _generateOrderId() async {
    final orderRef = FirebaseFirestore.instance.collection('pending_orders').doc();
    setState(() {
      _orderId = orderRef.id;
    });
    await orderRef.set({
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurantInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(widget.cart.restaurantId)
          .get();
      
      if (doc.exists) {
        setState(() {
          restaurant = Restaurant.fromFirestore(doc);
          isLoadingRestaurant = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement du restaurant: $e');
      setState(() => isLoadingRestaurant = false);
    }
  }

  Future<void> _calculateDistance() async {
    // Ne pas calculer si le restaurant n'est pas encore chargé
    if (restaurant == null) {
      setState(() => isCalculatingDistance = false);
      return;
    }

    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      // D'abord vérifier si on a déjà une localisation dans le provider
      if (locationProvider.hasLocation) {
        debugPrint('=== CALCUL DE DISTANCE ===');
        debugPrint('User coords: ${locationProvider.latitude}, ${locationProvider.longitude}');
        debugPrint('Restaurant coords: ${restaurant!.address.latitude}, ${restaurant!.address.longitude}');
        debugPrint('User address: ${locationProvider.address}');
        
        // Calculer la distance avec les coordonnées existantes du provider
        double distance = Geolocator.distanceBetween(
          locationProvider.latitude!,
          locationProvider.longitude!,
          restaurant!.address.latitude,
          restaurant!.address.longitude,
        );
        
        debugPrint('Distance brute: $distance mètres');
        debugPrint('Distance convertie: ${distance / 1000} km');
        
        setState(() {
          distanceInKm = distance / 1000; // Convertir en km
          isCalculatingDistance = false;
        });
        debugPrint('Distance calculée avec la localisation du provider: ${distanceInKm!.toStringAsFixed(1)} km');
        return;
      }
      
      // Si pas de localisation dans le provider, ne pas essayer automatiquement
      debugPrint('Aucune localisation dans le provider');
      setState(() => isCalculatingDistance = false);
      
    } catch (e) {
      debugPrint('Erreur lors du calcul de la distance: $e');
      setState(() => isCalculatingDistance = false);
    }
  }

  Future<void> _requestLocationAndCalculateDistance() async {
    if (restaurant == null) return;

    setState(() => isCalculatingDistance = true);

    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      // Demander la localisation à l'utilisateur
      debugPrint('=== DEMANDE DE GÉOLOCALISATION ===');
      await locationProvider.useCurrentLocation();
      
      if (locationProvider.hasLocation) {
        debugPrint('Géolocalisation réussie:');
        debugPrint('User coords: ${locationProvider.latitude}, ${locationProvider.longitude}');
        debugPrint('Restaurant coords: ${restaurant!.address.latitude}, ${restaurant!.address.longitude}');
        debugPrint('User address: ${locationProvider.address}');
        
        double distance = Geolocator.distanceBetween(
          locationProvider.latitude!,
          locationProvider.longitude!,
          restaurant!.address.latitude,
          restaurant!.address.longitude,
        );
        
        debugPrint('Distance brute: $distance mètres');
        debugPrint('Distance convertie: ${distance / 1000} km');
        
        setState(() {
          distanceInKm = distance / 1000; // Convertir en km
          isCalculatingDistance = false;
        });
        debugPrint('Distance calculée après géolocalisation: ${distanceInKm!.toStringAsFixed(1)} km');
      } else {
        setState(() => isCalculatingDistance = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'obtenir votre localisation'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la géolocalisation: $e');
      setState(() => isCalculatingDistance = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de localisation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyPromoCode() async {
    if (_promoCodeController.text.trim().isEmpty) return;

    setState(() => isApplyingPromo = true);

    try {
      // Simuler la vérification du code promo
      // TODO: Implémenter la logique réelle de vérification
      await Future.delayed(const Duration(seconds: 1));
      
      final promoCode = _promoCodeController.text.trim().toUpperCase();
      
      // Codes promo de démonstration
      double discount = 0.0;
      switch (promoCode) {
        case 'BIENVENUE10':
          discount = widget.cart.totalAmount * 0.10; // 10%
          break;
        case 'LIVRAISON':
          discount = deliveryFee; // Livraison gratuite
          break;
        case '5EUROS':
          discount = 5.0; // 5€ de réduction
          break;
        default:
          throw Exception('Code promo invalide');
      }

      setState(() {
        appliedPromoCode = promoCode;
        promoDiscount = discount;
        isApplyingPromo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Code promo appliqué ! -${discount.toStringAsFixed(2)}€'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => isApplyingPromo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removePromoCode() {
    setState(() {
      appliedPromoCode = null;
      promoDiscount = 0.0;
      _promoCodeController.clear();
    });
  }

  // Calculs TVA avec remise
  double get subtotalHT => widget.cart.totalAmountHT;
  double get subtotalTTC => widget.cart.totalAmountTTC;
  double get totalVatAmount => widget.cart.totalVatAmount;
  
  // La remise est appliquée sur le TTC, on recalcule HT et TVA proportionnellement
  double get finalTotalTTC => (subtotalTTC - promoDiscount).clamp(0.0, double.infinity);
  double get finalTotalHT => subtotalHT * (finalTotalTTC / subtotalTTC);
  double get finalVatAmount => totalVatAmount * (finalTotalTTC / subtotalTTC);
  double get finalTotal => finalTotalTTC;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Récapitulatif de commande',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black87),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UserRestaurantOrdersPage(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informations du restaurant
                  _buildRestaurantInfo(),
                  
                  SizedBox(height: 24.h),
                  
                  // Articles commandés
                  _buildOrderItems(),
                  
                  SizedBox(height: 24.h),
                  
                  // Code promo
                  _buildPromoCodeSection(),
                  
                  SizedBox(height: 24.h),
                  
                  // Heure de livraison
                  if (restaurant != null)
                    DeliveryTimeSelector(
                      restaurant: restaurant!,
                      selectedTime: _scheduledTime,
                      onTimeSelected: (time) {
                        setState(() {
                          _scheduledTime = time;
                        });
                        // Mettre à jour le panier
                        final cartService = Provider.of<CartRestaurantService>(context, listen: false);
                        cartService.updateDeliverySchedule(
                          restaurantId: widget.cart.restaurantId,
                          scheduledTime: time,
                          deliveryType: _deliveryType,
                        );
                      },
                      deliveryType: _deliveryType,
                      onDeliveryTypeChanged: (type) {
                        setState(() {
                          _deliveryType = type;
                          if (type == 'asap') {
                            _scheduledTime = null;
                          }
                        });
                        // Mettre à jour le panier
                        final cartService = Provider.of<CartRestaurantService>(context, listen: false);
                        cartService.updateDeliverySchedule(
                          restaurantId: widget.cart.restaurantId,
                          scheduledTime: _scheduledTime,
                          deliveryType: type,
                        );
                      },
                    ),
                  
                  SizedBox(height: 24.h),
                  
                  // Message client
                  CustomerMessageWidget(
                    initialMessage: widget.cart.customerMessage,
                    onMessageChanged: (message) {
                      setState(() {
                        _customerMessage = message;
                      });
                      // Mettre à jour le panier
                      final cartService = Provider.of<CartRestaurantService>(context, listen: false);
                      cartService.updateCustomerMessage(
                        restaurantId: widget.cart.restaurantId,
                        message: message,
                      );
                    },
                  ),
                  
                  SizedBox(height: 24.h),
                  
                  // Debug - Informations de localisation
 
                  
                  // Récapitulatif des coûts
                  _buildCostSummary(),
                ],
              ),
            ),
          ),
          
          // Bouton de commande
          _buildOrderButton(),
        ],
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    if (isLoadingRestaurant) {
      return _buildLoadingCard();
    }

    if (restaurant == null) {
      return _buildErrorCard('Impossible de charger les informations du restaurant');
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          Row(
            children: [
              // Logo du restaurant
              Container(
                width: 60.w,
                height: 60.h,
                decoration: BoxDecoration(
                  color: Colors.white,
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
                  child: restaurant!.logo.isNotEmpty
                      ? Image.network(
                          restaurant!.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              _buildDefaultRestaurantLogo(),
                        )
                      : _buildDefaultRestaurantLogo(),
                ),
              ),
              
              SizedBox(width: 16.w),
              
              // Informations du restaurant
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant!.name,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${restaurant!.address.address}, ${restaurant!.address.codePostal} ${restaurant!.address.ville}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (distanceInKm != null) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16.sp,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            '${distanceInKm!.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: _requestLocationAndCalculateDistance,
                            child: Icon(
                              Icons.refresh,
                              size: 14.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ] else if (isCalculatingDistance) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          SizedBox(
                            width: 12.w,
                            height: 12.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Calcul de la distance...',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(height: 4.h),
                      GestureDetector(
                        onTap: _requestLocationAndCalculateDistance,
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 16.sp,
                              color: Colors.grey[400],
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Calculer la distance',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[500],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Temps de livraison estimé
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
                  size: 20.sp,
                  color: Colors.green[600],
                ),
                SizedBox(width: 8.w),
                Text(
                  'Temps de préparation estimé: ${restaurant!.preparationTime} min',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          
      
        ],
      ),
    );
  }

  Widget _buildDefaultRestaurantLogo() {
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
            'Votre commande',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Liste des articles
          ...widget.cart.items.map((item) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: CartItemWidget(
              item: item,
              restaurantId: widget.cart.restaurantId,
              showControls: false, // Pas de contrôles sur la page checkout
            ),
          )),
          
          SizedBox(height: 12.h),
          
          // Sous-total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sous-total',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${widget.cart.totalAmount.toStringAsFixed(2)}€',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
            'Code promo',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          if (appliedPromoCode != null) ...[
            // Code promo appliqué
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
                    Icons.check_circle,
                    color: Colors.green[600],
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Code "$appliedPromoCode" appliqué',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'Économie: ${promoDiscount.toStringAsFixed(2)}€',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _removePromoCode,
                    icon: Icon(
                      Icons.close,
                      color: Colors.green[600],
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Champ de saisie du code promo
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoCodeController,
                    decoration: InputDecoration(
                      hintText: 'Entrez votre code promo',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14.sp,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 12.h,
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                SizedBox(width: 12.w),
                ElevatedButton(
                  onPressed: isApplyingPromo ? null : _applyPromoCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: isApplyingPromo
                      ? SizedBox(
                          width: 16.w,
                          height: 16.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Appliquer',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
            
            SizedBox(height: 8.h),
            
            // Codes promo de démonstration
            Text(
              'Codes de démonstration: BIENVENUE10, LIVRAISON, 5EUROS',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostSummary() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          
          // Sous-total HT
          _buildSummaryRow(
            'Sous-total HT',
            '${subtotalHT.toStringAsFixed(2)}€',
          ),
          
          // TVA
          _buildSummaryRow(
            'TVA',
            '${totalVatAmount.toStringAsFixed(2)}€',
            color: Colors.grey[600],
          ),
          
          // Sous-total TTC
          _buildSummaryRow(
            'Sous-total TTC',
            '${subtotalTTC.toStringAsFixed(2)}€',
            fontWeight: FontWeight.w600,
          ),
          
          // Réduction promo
          if (promoDiscount > 0)
            _buildSummaryRow(
              'Réduction ($appliedPromoCode)',
              '-${promoDiscount.toStringAsFixed(2)}€',
              color: Colors.green,
            ),
          
          Divider(height: 24.h, color: Colors.grey[300]),
          
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                '${finalTotal.toStringAsFixed(2)}€',
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

  Widget _buildSummaryRow(String label, String value, {Color? color, FontWeight? fontWeight}) {
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
              fontWeight: fontWeight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: fontWeight ?? FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderButton() {
    if (_orderId == null) {
      return SafeArea(
        child: Container(
          padding: EdgeInsets.all(16.w),
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
            height: 48.h,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    }

    // Vérifier que l'utilisateur est connecté
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return SafeArea(
        child: Container(
          padding: EdgeInsets.all(16.w),
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
            height: 48.h,
            child: Center(
              child: Text(
                'Utilisateur non connecté',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Vérifier si le restaurant est ouvert
    if (!_isRestaurantOpen()) {
      return SafeArea(
        child: Container(
          padding: EdgeInsets.all(16.w),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 48.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    'Restaurant fermé',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Réouverture ${_getNextOpeningTime()}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Vérifier si une heure est sélectionnée pour la livraison planifiée
    if (_deliveryType == 'scheduled' && _scheduledTime == null) {
      return SafeArea(
        child: Container(
          padding: EdgeInsets.all(16.w),
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
            height: 48.h,
            child: Center(
              child: Text(
                'Veuillez sélectionner une heure de retrait',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Container(
        padding: EdgeInsets.all(16.w),
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
          height: 48.h,
          child: UnifiedPaymentButton(
            type: 'restaurant_order',
            amount: (finalTotal * 100).round(),
            metadata: {
              'orderId': _orderId!,
              'userId': currentUser.uid,
              'companyId': widget.cart.restaurantId,
              'restaurantName': widget.cart.restaurantName,
              'promoCode': appliedPromoCode,
              'promoDiscount': promoDiscount,
              'deliveryType': _deliveryType,
              'scheduledTime': _scheduledTime?.toIso8601String(),
              'customerMessage': _customerMessage,
            },
            orderData: {
              'userId': currentUser.uid,
              'companyId': widget.cart.restaurantId,
              'restaurantName': widget.cart.restaurantName,
              'restaurantLogo': widget.cart.restaurantLogo,
              'customerInfo': {
                'firstName': Provider.of<UserModel>(context, listen: false).firstName,
                'lastName': Provider.of<UserModel>(context, listen: false).lastName,
                'email': Provider.of<UserModel>(context, listen: false).email,
                'phone': Provider.of<UserModel>(context, listen: false).phone,
              },
              'items': widget.cart.items.map((item) => {
                'id': item.id,
                'name': item.name,
                'unitPrice': item.unitPrice,
                'totalPrice': item.totalPrice,
                'totalPriceHT': item.totalPriceHT,
                'vatRate': item.vatRate,
                'vatAmount': item.vatAmount,
                'quantity': item.quantity,
                'type': item.type,
                'menuId': item.menuId,
                'variants': item.variants?.map((v) => {
                  'name': v.name,
                  'selectedOption': {
                    'name': v.selectedOption.name,
                    'priceModifier': v.selectedOption.priceModifier,
                  },
                }).toList(),
                'options': item.options?.map((o) => {
                  'templateName': o.templateName,
                  'item': {
                    'name': o.item.name,
                    'itemId': o.item.itemId,
                  },
                }).toList(),
                'updatedAt': item.updatedAt?.toIso8601String(),
              }).toList(),
              'subtotalHT': subtotalHT,
              'subtotalTTC': subtotalTTC,
              'vatAmount': totalVatAmount,
              'deliveryFee': deliveryFee,
              'serviceFee': serviceFee,
              'promoCode': appliedPromoCode,
              'discountAmount': promoDiscount,
              'finalTotalHT': finalTotalHT,
              'finalVatAmount': finalVatAmount,
              'totalPrice': finalTotal,
              'restaurantAddress': '${restaurant!.address.address} ${restaurant!.address.codePostal} ${restaurant!.address.ville}',
              'distance': distanceInKm,
              'deliveryType': _deliveryType,
              'scheduledTime': _scheduledTime?.toIso8601String(),
              'customerMessage': _customerMessage,
            },
            successUrl: '${kIsWeb ? Uri.base.origin : 'https://happy-deals.web.app'}/#/payment-success',
            cancelUrl: '${kIsWeb ? Uri.base.origin : 'https://happy-deals.web.app'}/#/payment-cancel',
            onBeforePayment: () => _verifyBeforePayment(),
            onError: (error) => _onPaymentError(error),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          Icon(Icons.error_outline, color: Colors.red, size: 24.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _verifyBeforePayment() async {
    try {
      // Vérifier que le restaurant est toujours actif
      if (restaurant == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de vérifier les informations du restaurant'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      // Vérifier si le restaurant est ouvert
      if (!_isRestaurantOpen()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Le restaurant est fermé. Réouverture ${_getNextOpeningTime()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      final doc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(widget.cart.restaurantId)
          .get();
      
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ce restaurant n\'est plus disponible'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      final isActive = data['isActive'] ?? true;
      
      if (!isActive) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ce restaurant est temporairement fermé'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Erreur lors de la vérification avant paiement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de vérification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  void _onPaymentError(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de paiement: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isRestaurantOpen() {
    if (restaurant == null) return false;
    return restaurant!.isOpen;
  }

  String _getNextOpeningTime() {
    if (restaurant == null) return '';
    
    final now = DateTime.now();
    final schedule = restaurant!.openingHours.schedule;
    const daysOfWeek = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday'
    ];
    
    // Chercher le prochain jour d'ouverture
    for (int i = 0; i < 7; i++) {
      final checkDate = DateTime(now.year, now.month, now.day + i);
      final dayName = daysOfWeek[checkDate.weekday - 1];
      final hours = schedule[dayName];
      
      if (hours != null && hours != 'fermé') {
        final timeRanges = hours.split(',');
        if (timeRanges.isNotEmpty) {
          final firstRange = timeRanges.first.trim().split('-');
          if (firstRange.length == 2) {
            final openTime = firstRange[0].trim();
            final dayName = _getDayNameInFrench(checkDate.weekday);
            return '$dayName à $openTime';
          }
        }
      }
    }
    
    return 'Prochainement';
  }

  String _getDayNameInFrench(int weekday) {
    const days = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche'
    ];
    return days[weekday - 1];
  }
}