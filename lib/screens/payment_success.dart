import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/screens/shop/order_confirmation_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  _PaymentSuccessScreenState createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _verifyPaymentAndFinalizeOrder();
  }

  Future<void> _verifyPaymentAndFinalizeOrder() async {
    final functions = FirebaseFunctions.instance;
    final cart = Provider.of<CartService>(context, listen: false);

    try {
      final sessionId = html.window.localStorage['stripeSessionId'];
      if (sessionId == null) {
        throw Exception('Session ID not found');
      }

      final result = await functions.httpsCallable('verifyPayment').call({
        'sessionId': sessionId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérification du paiement en cours...')),
      );

      if (result.data['success'] == true) {
        await _finalizeOrder(cart);
        // Ne pas naviguer ici, car _finalizeOrder s'en charge déjà
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Le paiement a échoué. Veuillez réessayer.')),
        );
        Navigator.of(context).pushReplacementNamed('/checkout');
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Veuillez vous connecter pour finaliser votre commande.')),
        );
        // Rediriger vers la page de connexion
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Une erreur est survenue: ${e.message}')),
        );
        Navigator.of(context).pushReplacementNamed('/checkout');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Une erreur inattendue est survenue: $e')),
      );
      Navigator.of(context).pushReplacementNamed('/checkout');
    } finally {
      // Nettoyage du sessionId du localStorage
      html.window.localStorage.remove('stripeSessionId');
    }
  }

  Future<void> _finalizeOrder(CartService cart) async {
    final user = _auth.currentUser;
    final address =
        await _fetchCompanyAddress(cart.items.first.product.entrepriseId);

    final orderId = await _orderService.createOrder(Orders(
      id: '',
      userId: user != null ? user.uid : '',
      sellerId: cart.items.first.product.sellerId,
      items: cart.items
          .map((item) => OrderItem(
                productId: item.product.id,
                name: item.product.name,
                quantity: item.quantity,
                price: item.product.price,
              ))
          .toList(),
      totalPrice: cart.total,
      status: 'paid',
      createdAt: DateTime.now(),
      pickupAddress: address ?? "",
    ));

    cart.clearCart();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(orderId: orderId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traitement du paiement')),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Future<String?> _fetchCompanyAddress(String entrepriseId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(entrepriseId)
          .get();

      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('adress')) {
          Map<String, dynamic> addressMap =
              data['adress'] as Map<String, dynamic>;
          String adresse = addressMap['adresse'] ?? '';
          String codePostal = addressMap['codePostal'] ?? '';
          String ville = addressMap['ville'] ?? '';
          return '$adresse, $codePostal $ville';
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération de l'adresse de l'entreprise: $e");
    }
    return null;
  }
}
