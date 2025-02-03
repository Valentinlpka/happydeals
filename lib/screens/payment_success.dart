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
    if (widget.orderId != null) {
      _paymentDetails = {
        'type': 'order',
        'metadata': {'orderId': widget.orderId},
      };
    } else if (widget.reservationId != null) {
      _paymentDetails = {
        'type': 'express_deal',
        'metadata': {'reservationId': widget.reservationId},
      };
    } else if (widget.bookingId != null) {
      _paymentDetails = {
        'type': 'service',
        'metadata': {'bookingId': widget.bookingId},
      };
    }
    _verifyPayment();
  }

  String? _getSessionId() {
    if (!kIsWeb) return widget.sessionId;

    try {
      final uri = Uri.parse(html.window.location.href);
      final params = uri.queryParameters;

      print('URL params: $params'); // Debug log

      if (_paymentDetails == null) {
        if (params['orderId'] != null) {
          print('Found orderId: ${params['orderId']}'); // Debug log
          _paymentDetails = {
            'type': 'order',
            'metadata': {'orderId': params['orderId']},
          };
        } else if (params['reservationId'] != null) {
          print('Found reservationId: ${params['reservationId']}'); // Debug log
          _paymentDetails = {
            'type': 'express_deal',
            'metadata': {'reservationId': params['reservationId']},
          };
        } else if (params['bookingId'] != null) {
          print('Found bookingId: ${params['bookingId']}'); // Debug log
          _paymentDetails = {
            'type': 'service',
            'metadata': {'bookingId': params['bookingId']},
          };
        }
      }

      print('Final paymentDetails: $_paymentDetails'); // Debug log
      return params['session_id'];
    } catch (e) {
      print('Error parsing URL: $e'); // Debug log
      return null;
    }
  }

  Future<void> _verifyPayment() async {
    try {
      print('Début de _verifyPayment');
      print('PaymentDetails initial: $_paymentDetails');

      if (_auth.currentUser == null) {
        throw Exception('Utilisateur non authentifié');
      }

      // Si nous avons déjà les détails du paiement (via les paramètres du widget)
      if (_paymentDetails != null) {
        print('Utilisation des détails existants: $_paymentDetails');

        switch (_paymentDetails!['type']) {
          case 'order':
            final orderId = _paymentDetails!['metadata']['orderId'];
            print('Attente de la création de la commande: $orderId');
            await _waitForOrder(orderId);
            if (mounted) {
              print('Redirection vers OrderDetailPage');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailPage(orderId: orderId),
                ),
              );
            }
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
        return; // Sortir de la fonction si nous avons déjà traité les détails
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

      // Rediriger selon le type
      switch (_paymentType) {
        case 'order':
          final orderId = _paymentDetails!['metadata']['orderId'];
          // Attendre que la commande soit créée
          await _waitForOrder(orderId);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailPage(orderId: orderId),
              ),
            );
          }
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

      _showSuccessMessage();
    } catch (e) {
      _handleError('Une erreur est survenue: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _getPaymentDetails(String sessionId) async {
    try {
      print('Recherche des détails pour la session: $sessionId');

      // Vérifier d'abord dans pending_orders
      final orderDoc = await _firestore
          .collection('pending_orders') // Changé de 'pending_order_payments'
          .doc(sessionId)
          .get();

      if (orderDoc.exists) {
        final data = orderDoc.data()!;
        print('Détails de commande trouvés: $data');
        return {
          ...data,
          'type': 'order',
        };
      }

      // Si pas trouvé, vérifier les autres collections...
      final typeMap = {
        'pending_express_deal_payments': 'express_deal',
        'pending_service_payments': 'service'
      };

      for (String collection in typeMap.keys) {
        final doc =
            await _firestore.collection(collection).doc(sessionId).get();
        if (doc.exists) {
          return {...doc.data()!, 'type': typeMap[collection]};
        }
      }

      print('Aucun détail trouvé pour la session: $sessionId');
      return null;
    } catch (e) {
      print('Error getting payment details: $e');
      return null;
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
    print('Erreur dans payment_success: $message');
    setState(() {
      _statusMessage = message;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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

  // Nouvelle fonction pour attendre la création de la commande
  Future<void> _waitForOrder(String orderId) async {
    print('Début de _waitForOrder pour orderId: $orderId');
    const maxAttempts = 10;
    const delaySeconds = 2;
    int attempts = 0;

    while (attempts < maxAttempts) {
      print('Tentative ${attempts + 1}/$maxAttempts');
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();

      if (orderDoc.exists) {
        print('Commande trouvée après ${attempts + 1} tentatives');
        return;
      }

      print(
          'Commande non trouvée, nouvelle tentative dans $delaySeconds secondes...');
      await Future.delayed(const Duration(seconds: delaySeconds));
      attempts++;
    }

    throw Exception(
        'La commande n\'a pas été créée après ${maxAttempts * delaySeconds} secondes');
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
