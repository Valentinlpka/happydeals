import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:universal_html/html.dart' as html;

class UnifiedPaymentButton extends StatefulWidget {
  final String type; // 'order', 'express_deal', or 'service'
  final int amount;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? orderData; // Nouveau paramètre
  final String successUrl;
  final String cancelUrl;
  final VoidCallback? onSuccess;
  final Function(String)? onError;

  const UnifiedPaymentButton({
    super.key,
    required this.type,
    required this.amount,
    required this.metadata,
    this.orderData,
    required this.successUrl,
    required this.cancelUrl,
    this.onSuccess,
    this.onError,
  });

  @override
  State<UnifiedPaymentButton> createState() => _UnifiedPaymentButtonState();
}

class _UnifiedPaymentButtonState extends State<UnifiedPaymentButton> {
  bool _isLoading = false;

  Future<void> _handlePayment() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // Stocker les données selon le type
      switch (widget.type) {
        case 'order':
          await FirebaseFirestore.instance
              .collection('pending_orders')
              .doc(widget.metadata['orderId'])
              .set({
            ...widget.orderData!,
            'items': widget.orderData!['items']
                .map((item) => {
                      ...item,
                      'tva': item['tva'] ?? 20.0,
                    })
                .toList(),
            'status': 'pending'
          });
          break;

        case 'express_deal':
          break;

        case 'service':
          await FirebaseFirestore.instance
              .collection('pending_services')
              .doc(widget.metadata['serviceId'])
              .set({
            'userId': FirebaseAuth.instance.currentUser?.uid,
            'serviceId': widget.metadata['serviceId'],
            'serviceName': widget.metadata['serviceName'],
            'bookingDateTime': widget.metadata['bookingDateTime'],
            'professionalId': widget.metadata['professionalId'],
            'amount': widget.amount / 100,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
          break;
      }

      // Créer la session de paiement
      final result = await FirebaseFunctions.instance
          .httpsCallable('createUnifiedPayment')
          .call({
        'type': widget.type,
        'amount': widget.amount,
        'metadata': widget.metadata,
        'successUrl': widget.successUrl,
        'cancelUrl': widget.cancelUrl,
        'isWeb': kIsWeb,
      });

      if (kIsWeb) {
        final String checkoutUrl = result.data['url'];
        html.window.location.href = checkoutUrl;
      } else {
        // Gestion mobile avec Stripe SDK
        try {
          // Initialiser la feuille de paiement
          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              merchantDisplayName: 'Happy Deals',
              paymentIntentClientSecret: result.data['clientSecret'],
              style: ThemeMode.system,
            ),
          );

          // Afficher la feuille de paiement
          await Stripe.instance.presentPaymentSheet();

          // Si le paiement est réussi
          if (widget.type == 'order') {
            try {
              // Créer d'abord la commande dans orders
              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.metadata['orderId'])
                  .set({
                'userId': FirebaseAuth.instance.currentUser?.uid,
                'items': widget.orderData?['items'] ?? [],
                'sellerId': widget.orderData?['sellerId'],
                'entrepriseId': widget.orderData?['entrepriseId'],
                'subtotal': widget.orderData?['subtotal'],
                'promoCode': widget.orderData?['promoCode'],
                'discountAmount': widget.orderData?['discountAmount'],
                'totalPrice': widget.orderData?['totalPrice'],
                'pickupAddress': widget.orderData?['pickupAddress'],
                'status': 'paid',
                'createdAt': FieldValue.serverTimestamp(),
              });

              // Créer l'entrée dans pending_orders
              await FirebaseFirestore.instance
                  .collection('pending_orders')
                  .doc(result.data['sessionId'])
                  .set({
                'userId': FirebaseAuth.instance.currentUser?.uid,
                'metadata': {
                  'orderId': widget.metadata['orderId'],
                  'cartId': widget.metadata['cartId'],
                },
                'status': 'pending',
                'type': 'order',
                'amount': widget.amount,
                'createdAt': FieldValue.serverTimestamp(),
              });

              // Supprimer le panier
              if (widget.metadata['cartId'] != null) {
                await FirebaseFirestore.instance
                    .collection('carts')
                    .doc(widget.metadata['cartId'])
                    .delete();
              }

              // Navigation vers la page de succès
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/payment-success',
                  (route) => false,
                  arguments: {'sessionId': result.data['sessionId']},
                );
              }
            } catch (e) {
              print('Erreur lors de la création de la commande: $e');
              widget.onError
                  ?.call('Erreur lors de la finalisation de la commande');
            }
          }
        } on StripeException catch (e) {
          if (e.error.code == 'Canceled') {
            widget.onError?.call('Paiement annulé');
          } else {
            widget.onError
                ?.call(e.error.localizedMessage ?? 'Erreur de paiement');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Une erreur est survenue';
        if (e is FirebaseFunctionsException) {
          errorMessage = e.message ?? errorMessage;
        }
        widget.onError?.call(errorMessage);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handlePayment,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[800],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              'Payer ${(widget.amount / 100).toStringAsFixed(2)} €',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }
}
