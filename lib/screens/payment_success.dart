import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/booking_detail_page.dart';
import 'package:happy/screens/details_page/details_reservation_dealexpress_page.dart';
import 'package:happy/screens/shop/order_detail_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

class UnifiedPaymentSuccessScreen extends StatefulWidget {
  final String? sessionId;
  final String? orderId;
  final String? reservationId;
  final String? bookingId;

  const UnifiedPaymentSuccessScreen({
    this.sessionId,
    this.orderId,
    this.reservationId,
    this.bookingId,
    super.key,
  });

  @override
  State<UnifiedPaymentSuccessScreen> createState() =>
      _UnifiedPaymentSuccessScreenState();
}

class _UnifiedPaymentSuccessScreenState
    extends State<UnifiedPaymentSuccessScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  String _statusMessage = 'Vérification du paiement...';
  String? _paymentType;
  Map<String, dynamic>? _paymentDetails;

  @override
  void initState() {
    super.initState();
    _initializePaymentDetails();
  }

  Future<void> _initializePaymentDetails() async {
    try {
      // Vérifier d'abord les paramètres d'URL pour le web
      if (kIsWeb) {
        final uri = Uri.parse(html.window.location.href);
        final params = uri.queryParameters;

        if (params['orderId'] != null) {
          _paymentDetails = {
            'orderId': params['orderId'],
          };
        }
      }

      // Pour mobile, vérifier l'ID passé en paramètre
      if (_paymentDetails == null) {
        if (widget.orderId != null) {
          _paymentDetails = {
            'orderId': widget.orderId,
          };
        }
      }

      if (_paymentDetails != null) {
        await _verifyPayment();
      } else {
        _handleError('Aucun détail de paiement trouvé');
      }
    } catch (e) {
      _handleError('Erreur lors de l\'initialisation: $e');
    }
  }

  Future<void> _verifyPayment() async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('Utilisateur non authentifié');
      }

      if (_paymentDetails == null) {
        throw Exception('Détails du paiement non trouvés');
      }

      await _handleOrderSuccess(_paymentDetails!['orderId']);
    } catch (e) {
      _handleError('Erreur lors de la vérification: $e');
    }
  }

  Future<void> _handleOrderSuccess(String orderId) async {
    try {
      // Attendre que la commande soit créée dans la collection orders
      await _waitForDocument('orders', orderId);

      // Récupérer les détails de la commande pour déterminer le type
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Commande non trouvée');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final orderType = orderData['type'] as String;

      // Supprimer le panier si c'est une commande classique
      if (orderType == 'order') {
        final cartService = Provider.of<CartService>(context, listen: false);
        final sellerId = orderData['sellerId'] as String;
        await cartService.deleteCart(sellerId);
      }

      if (mounted) {
        // Rediriger vers la page de détails appropriée selon le type
        Widget detailPage;
        switch (orderType) {
          case 'order':
            detailPage = OrderDetailPage(orderId: orderId);
            break;
          case 'express_deal':
            detailPage = ReservationDetailsPage(reservationId: orderId);
            break;
          case 'service':
            detailPage = BookingDetailPage(bookingId: orderId);
            break;
          default:
            detailPage = OrderDetailPage(orderId: orderId);
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => detailPage),
          (route) => false,
        );
      }
    } catch (e) {
      _handleError('Erreur lors de la redirection: $e');
    }
  }

  Future<void> _waitForDocument(String collection, String documentId) async {
    const maxAttempts = 10;
    const delaySeconds = 2;
    int attempts = 0;

    while (attempts < maxAttempts) {
      final doc = await _firestore.collection(collection).doc(documentId).get();
      if (doc.exists) {
        setState(() => _isLoading = false);
        return;
      }
      await Future.delayed(const Duration(seconds: delaySeconds));
      attempts++;
    }

    throw Exception('Document non trouvé après ${maxAttempts * delaySeconds} secondes');
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            'Commande confirmée !',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Votre commande a été enregistrée avec succès.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/home'),
            child: const Text('Retourner à l\'accueil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirmation'),
          automaticallyImplyLeading: !_isLoading,
          actions: [
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/home'),
                tooltip: 'Retour à l\'accueil',
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child:
                _isLoading ? _buildLoadingIndicator() : _buildSuccessContent(),
          ),
        ),
      ),
    );
  }
}
