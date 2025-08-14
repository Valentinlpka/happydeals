import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/screens/restaurant_order_detail_page.dart';

class RestaurantOrderWaitingPage extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? orderData;

  const RestaurantOrderWaitingPage({
    super.key,
    required this.orderId,
    this.orderData,
  });

  @override
  State<RestaurantOrderWaitingPage> createState() => _RestaurantOrderWaitingPageState();
}

class _RestaurantOrderWaitingPageState extends State<RestaurantOrderWaitingPage>
    with TickerProviderStateMixin {
  
  StreamSubscription<DocumentSnapshot>? _orderSubscription;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  String _currentStatus = 'pending'; // ignore: unused_field
  String _statusMessage = 'Transmission de votre commande...';
  bool _isConfirmed = false;
  int _dotsCount = 0;
  Timer? _dotsTimer;
  
  // Messages d'attente rotatifs
  final List<String> _waitingMessages = [
    'Transmission de votre commande...',
    'Le restaurant examine votre demande...',
    'Préparation de votre commande en cours...',
    'Vérification de la disponibilité...',
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startListeningToOrder();
    _startDotsAnimation();
    _startMessageRotation();
  }

  void _setupAnimations() {
    // Animation de pulsation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    // Animation de fade
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.repeat(reverse: true);

    // Animation de scale pour la confirmation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  void _startListeningToOrder() {
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'pending';
          final pickupTime = data['pickupTime'] as String?;
          
          setState(() {
            _currentStatus = status;
          });

          if (status == 'confirmed' && pickupTime != null && !_isConfirmed) {
            _handleOrderConfirmed(pickupTime);
          } else if (status == 'rejected') {
            _handleOrderRejected();
          }
        }
      },
      onError: (error) {
        debugPrint('Erreur lors de l\'écoute de la commande: $error');
        _showErrorDialog('Erreur de connexion');
      },
    );
  }

  void _startDotsAnimation() {
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && !_isConfirmed) {
        setState(() {
          _dotsCount = (_dotsCount + 1) % 4;
        });
      }
    });
  }

  void _startMessageRotation() {
    _messageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && !_isConfirmed) {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _waitingMessages.length;
          _statusMessage = _waitingMessages[_currentMessageIndex];
        });
      }
    });
  }

  void _handleOrderConfirmed(String pickupTime) {
    setState(() {
      _isConfirmed = true;
      _statusMessage = 'Commande confirmée !';
    });
    
    _pulseController.stop();
    _fadeController.stop();
    _scaleController.forward();
    _dotsTimer?.cancel();
    _messageTimer?.cancel();

    // Attendre un peu avant de rediriger
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                RestaurantOrderDetailPage(orderId: widget.orderId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeInOut,
                )),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
  }

  void _handleOrderRejected() {
    setState(() {
      _statusMessage = 'Commande refusée';
    });
    
    _pulseController.stop();
    _fadeController.stop();
    _dotsTimer?.cancel();
    _messageTimer?.cancel();

    _showErrorDialog('Désolé, le restaurant ne peut pas prendre votre commande en charge actuellement.');
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Information'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/home');
            },
            child: const Text('Retour à l\'accueil'),
          ),
        ],
      ),
    );
  }

  String get _dotsString => '.' * _dotsCount;

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _dotsTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                // Header avec logo
                _buildHeader(),
                
                const Spacer(flex: 2),
                
                // Animation principale
                _buildMainAnimation(),
                
                SizedBox(height: 48.h),
                
                // Message de statut
                _buildStatusMessage(),
                
                SizedBox(height: 24.h),
                
                // Informations de commande
                if (widget.orderData != null) _buildOrderInfo(),
                
                const Spacer(flex: 3),
                
                // Bouton d'annulation (optionnel)
                _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48.w,
          height: 48.h,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.restaurant,
            color: Colors.blue[600],
            size: 24.sp,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande en cours',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Commande #${widget.orderId.substring(0, 8)}',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainAnimation() {
    if (_isConfirmed) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 120.w,
          height: 120.h,
          decoration: BoxDecoration(
            color: Colors.green[50],
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 20.r,
                spreadRadius: 5.r,
              ),
            ],
          ),
          child: Icon(
            Icons.check_circle,
            size: 60.sp,
            color: Colors.green[600],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 120.w,
              height: 120.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[400]!,
                    Colors.blue[600]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20.r,
                    spreadRadius: 5.r,
                  ),
                ],
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 50.sp,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusMessage() {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            _isConfirmed ? _statusMessage : '$_statusMessage$_dotsString',
            key: ValueKey(_statusMessage),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: _isConfirmed ? Colors.green[700] : Colors.blue[700],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (!_isConfirmed) ...[
          SizedBox(height: 16.h),
          Text(
            'Le restaurant va confirmer votre commande sous peu',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildOrderInfo() {
    final orderData = widget.orderData!;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store,
                size: 20.sp,
                color: Colors.grey[600],
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  orderData['restaurantName'] ?? 'Restaurant',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '${orderData['totalPrice']?.toStringAsFixed(2) ?? '0.00'}€',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          if (orderData['deliveryType'] == 'scheduled' && orderData['scheduledTime'] != null) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16.sp,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 8.w),
                Text(
                  'Livraison programmée',
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
    );
  }

  Widget _buildCancelButton() {
    if (_isConfirmed) return const SizedBox.shrink();
    
    return TextButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Annuler la commande'),
            content: const Text('Êtes-vous sûr de vouloir annuler cette commande ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Non'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                child: const Text(
                  'Oui, annuler',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      child: Text(
        'Annuler la commande',
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 14.sp,
        ),
      ),
    );
  }
}