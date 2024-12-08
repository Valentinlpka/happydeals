import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/screens/shop/cart_models.dart';
import 'package:happy/screens/shop/order_detail_page.dart';
import 'package:happy/services/order_service.dart';
import 'package:happy/services/promo_service.dart';
import 'package:universal_html/html.dart' as html;

class PaymentSuccessScreen extends StatefulWidget {
  final String? sessionId;

  const PaymentSuccessScreen({
    this.sessionId,
    super.key,
  });

  @override
  _PaymentSuccessScreenState createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  String? _getSessionId() {
    if (kIsWeb) {
      // Récupérer l'URL complète
      String url = html.window.location.href;
      print('URL complète: $url'); // Pour déboguer

      // Parser l'URL pour extraire le session_id après le hash
      try {
        // Trouver la partie après le hash
        String hashPart = url.split('#')[1];
        // Trouver la partie après le ?
        String queryPart = hashPart.split('?')[1];
        // Parser les paramètres
        Map<String, String> params = Uri.splitQueryString(queryPart);
        String? sessionId = params['session_id'];
        print('Session ID trouvé: $sessionId'); // Pour déboguer
        return sessionId;
      } catch (e) {
        print('Erreur parsing URL: $e');
        return null;
      }
    }
    return null;
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrderService _orderService = OrderService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PromoCodeService _promoCodeService = PromoCodeService();

  bool _isLoading = true;
  String _statusMessage = 'Vérification du paiement en cours...';

  @override
  void initState() {
    super.initState();
    _verifyPaymentAndFinalizeOrder();
  }

  Future<void> _verifyPaymentAndFinalizeOrder() async {
    try {
      print('Début de la vérification du paiement');

      if (_auth.currentUser == null) {
        throw Exception('Utilisateur non authentifié');
      }

      // Utiliser la nouvelle méthode pour obtenir le sessionId
      final stripeSessionId = _getSessionId();
      if (stripeSessionId == null) {
        throw Exception('Session de paiement non trouvée');
      }

      // Trouver le panier correspondant dans Firestore
      final cartSnapshot = await _firestore
          .collection('carts')
          .where('stripeSessionId', isEqualTo: stripeSessionId)
          .limit(1)
          .get();

      if (cartSnapshot.docs.isEmpty) {
        throw Exception('Panier non trouvé');
      }

      final cartDoc = cartSnapshot.docs.first;
      final cart = await Cart.fromFirestore(cartDoc);

      if (cart == null) {
        throw Exception('Erreur lors de la récupération du panier');
      }

      if (cart.isExpired) {
        throw Exception('Le panier a expiré');
      }

      setState(() =>
          _statusMessage = 'Paiement confirmé. Finalisation de la commande...');

      await _finalizeOrder(cart);
      print('Commande finalisée avec succès');

      await _finalizePromoCodeUsage(cart);
      print('Utilisation du code promo finalisée');

      // Supprimer le panier de Firestore
      await cartDoc.reference.delete();

      _showSuccessMessage();
    } catch (e) {
      print('Erreur: $e');
      _handleError('Une erreur est survenue: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizeOrder(Cart cart) async {
    final user = _auth.currentUser!;
    final address = await _fetchCompanyAddress(cart.entrepriseId);

    // Vérifier une dernière fois les détails du code promo si présent
    double finalDiscountAmount = cart.discountAmount;
    if (cart.appliedPromoCode != null) {
      final promoDetails =
          await _promoCodeService.getPromoCodeDetails(cart.appliedPromoCode!);
      if (promoDetails != null) {
        // Recalculer la réduction pour s'assurer qu'elle est correcte
        if (promoDetails['isPercentage']) {
          finalDiscountAmount = cart.subtotal * (promoDetails['value'] / 100);
        } else {
          finalDiscountAmount = promoDetails['value'].toDouble();
        }
      }
    }

    final orderId = await _orderService.createOrder(Orders(
      id: '',
      userId: user.uid,
      sellerId: cart.sellerId,
      items: cart.items
          .map((item) => OrderItem(
                productId: item.product.id,
                image: item.product.imageUrl[0],
                name: item.product.name,
                quantity: item.quantity,
                originalPrice: item.product.price.toDouble(),
                appliedPrice: item.appliedPrice.toDouble(),
                tva: item.product.tva.toDouble(),
              ))
          .toList(),
      subtotal: cart.subtotal.toDouble(),
      happyDealSavings: cart.totalSavings.toDouble(),
      totalPrice: cart.totalAfterDiscount.toDouble(),
      status: 'paid',
      createdAt: DateTime.now(),
      pickupAddress: address ?? "",
      entrepriseId: cart.entrepriseId,
      promoCode: cart.appliedPromoCode,
      discountAmount: finalDiscountAmount,
    ));

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => OrderDetailPage(orderId: orderId)),
    );
  }

  Future<void> _finalizePromoCodeUsage(Cart cart) async {
    if (cart.appliedPromoCode != null) {
      try {
        // Vérifier une dernière fois la validité du code
        final isValid = await _promoCodeService.validatePromoCode(
          cart.appliedPromoCode!,
          cart.sellerId,
          _auth.currentUser?.uid ?? '',
        );

        if (!isValid) {
          print('Code promo invalide au moment de la finalisation');
          return;
        }

        // Marquer le code comme utilisé avec le companyId
        await _promoCodeService.usePromoCode(
          cart.appliedPromoCode!,
          cart.sellerId,
        );

        print('Code promo ${cart.appliedPromoCode} utilisé avec succès');
      } catch (e) {
        print('Erreur lors de la finalisation du code promo: $e');
        // On ne relance pas l'exception pour ne pas bloquer la finalisation de la commande
      }
    }
  }

  Future<String?> _fetchCompanyAddress(String entrepriseId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('companys').doc(entrepriseId).get();
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('adress')) {
          Map<String, dynamic> addressMap =
              data['adress'] as Map<String, dynamic>;
          return '${addressMap['adresse'] ?? ''}, ${addressMap['codePostal'] ?? ''} ${addressMap['ville'] ?? ''}';
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération de l'adresse: $e");
    }
    return null;
  }

  void _handleError(String message) {
    setState(() {
      _statusMessage = message;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  void _showSuccessMessage() {
    setState(() => _statusMessage = 'Commande finalisée avec succès!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traitement du paiement')),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_statusMessage),
                ],
              )
            : Text(_statusMessage),
      ),
    );
  }
}
