import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:happy/screens/booking_detail_page.dart';
import 'package:happy/screens/details_page/details_reservation_dealexpress_page.dart';
import 'package:happy/screens/shop/order_detail_page.dart';
import 'package:universal_html/html.dart' as html;

class UnifiedPaymentSuccessScreen extends StatefulWidget {
  final String? sessionId;

  const UnifiedPaymentSuccessScreen({
    this.sessionId,
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
    _verifyPayment();
  }

  String? _getSessionId() {
    if (!kIsWeb) return widget.sessionId;

    try {
      String url = html.window.location.href;
      String hashPart = url.split('#')[1];
      String queryPart = hashPart.split('?')[1];
      Map<String, String> params = Uri.splitQueryString(queryPart);
      return params['session_id'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _verifyPayment() async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('Utilisateur non authentifié');
      }

      final sessionId = _getSessionId();
      if (sessionId == null) {
        throw Exception('Session de paiement non trouvée');
      }

      // Vérifier le type de paiement
      final paymentDetails = await _getPaymentDetails(sessionId);
      if (paymentDetails == null) {
        throw Exception('Détails du paiement non trouvés');
      }

      setState(() {
        _paymentType = paymentDetails['type'];
        _paymentDetails = paymentDetails;
        _statusMessage = 'Finalisation de votre commande...';
      });

      // Gérer en fonction du type
      switch (_paymentType) {
        case 'order':
          await _handleOrderSuccess();
          break;
        case 'express_deal':
          await _handleExpressDealSuccess();
          break;
        case 'service':
          await _handleServiceSuccess();
          break;
        default:
          throw Exception('Type de paiement inconnu');
      }

      // Afficher le succès
      _showSuccessMessage();
    } catch (e) {
      _handleError('Une erreur est survenue: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _getPaymentDetails(String sessionId) async {
    // Map pour convertir les noms de collections en types
    final typeMap = {
      'pending_order_payments': 'order',
      'pending_express_deal_payments': 'express_deal',
      'pending_service_payments': 'service'
    };

    // Vérifier dans les trois collections de paiements en attente
    for (String collection in typeMap.keys) {
      final doc = await _firestore.collection(collection).doc(sessionId).get();
      if (doc.exists) {
        return {
          ...doc.data()!,
          'type': typeMap[collection] // Utiliser le type mappé au lieu de split
        };
      }
    }
    return null;
  }

  Future<void> _handleOrderSuccess() async {
    if (_paymentDetails == null) return;

    final orderId = _paymentDetails!['metadata']['orderId'];
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'paid',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Nettoyer le panier si nécessaire
    final cartId = _paymentDetails!['cartId'];
    if (cartId != null) {
      await _firestore.collection('carts').doc(cartId).delete();
    }

    // Rediriger vers les détails de la commande
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailPage(
            orderId: orderId,
          ),
        ),
      );
    }
  }

  Future<void> _handleExpressDealSuccess() async {
    if (_paymentDetails == null) return;
    final reservationId = _paymentDetails!['metadata']['reservationId'];

    // Mettre à jour le compteur de paniers
    await _firestore
        .collection('posts')
        .doc(_paymentDetails!['metadata']['postId'])
        .update({
      'basketCount': FieldValue.increment(-1),
    });

    // Rediriger vers les détails de la réservation
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReservationDetailsPage(
            reservationId: reservationId,
          ),
        ),
      );
    }
  }

  Future<void> _handleServiceSuccess() async {
    if (_paymentDetails == null) return;
    final bookingId = _paymentDetails!['metadata']['bookingId'];

    // Rediriger vers les détails de la réservation
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPage(bookingId: bookingId),
        ),
      );
    }
  }

  void _handleError(String message) {
    setState(() {
      _statusMessage = message;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

      // Rediriger vers l'accueil après un délai
      Future.delayed(const Duration(seconds: 3), () {
        Navigator.of(context).pushReplacementNamed('/home');
      });
    }
  }

  void _showSuccessMessage() {
    String message;
    switch (_paymentType) {
      case 'order':
        message = 'Votre commande a été confirmée !';
        break;
      case 'express_deal':
        message = 'Votre réservation express a été confirmée !';
        break;
      case 'service':
        message = 'Votre réservation de service a été confirmée !';
        break;
      default:
        message = 'Paiement confirmé !';
    }
    setState(() => _statusMessage = message);
  }

  Widget _buildLoadingIndicator() {
    return Column(
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
    );
  }

  Widget _buildSuccessContent() {
    final IconData icon;
    final String title;
    final String subtitle;

    switch (_paymentType) {
      case 'order':
        icon = Icons.shopping_bag_outlined;
        title = 'Commande confirmée !';
        subtitle = 'Votre commande a été enregistrée avec succès.';
        break;
      case 'express_deal':
        icon = Icons.flash_on;
        title = 'Réservation express confirmée !';
        subtitle = 'Votre panier vous attend au point de retrait.';
        break;
      case 'service':
        icon = Icons.event_available;
        title = 'Réservation confirmée !';
        subtitle = 'Votre rendez-vous a été enregistré.';
        break;
      default:
        icon = Icons.check_circle_outline;
        title = 'Paiement confirmé !';
        subtitle = 'Merci pour votre confiance.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/home'),
            child: const Text('Retourner à l\'accueil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmation'),
        automaticallyImplyLeading: !_isLoading,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isLoading ? _buildLoadingIndicator() : _buildSuccessContent(),
        ),
      ),
    );
  }
}
