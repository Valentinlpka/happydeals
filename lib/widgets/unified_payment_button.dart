import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:happy/screens/payment_success.dart';
import 'package:universal_html/html.dart' as html;

class UnifiedPaymentButton extends StatefulWidget {
  final String type; // 'order', 'express_deal', or 'service'
  final int amount;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic>? orderData;
  final String successUrl;
  final String cancelUrl;
  final VoidCallback? onSuccess;
  final Function(String)? onError;
  final Future<bool> Function()? onBeforePayment;

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
    this.onBeforePayment,
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
      if (widget.onBeforePayment != null) {
        final canProceed = await widget.onBeforePayment!();
        if (!canProceed) {
          setState(() => _isLoading = false);
          return;
        }
      }

      String? orderId;
      String successUrlWithParams = widget.successUrl;

      // Créer le document en attente dans une collection unifiée
      switch (widget.type) {
        case 'order':
          orderId = FirebaseFirestore.instance.collection('pending_orders').doc().id;
          widget.metadata['orderId'] = orderId;
          successUrlWithParams = '${widget.successUrl}?orderId=$orderId';

          await FirebaseFirestore.instance
              .collection('pending_orders')
              .doc(orderId)
              .set({
            'type': 'order',
            'userId': FirebaseAuth.instance.currentUser?.uid,
            'items': widget.orderData!['items'],
            'sellerId': widget.orderData!['sellerId'],
            'entrepriseId': widget.orderData!['entrepriseId'],
            'subtotal': widget.orderData!['subtotal'],
            'promoCode': widget.orderData!['promoCode'],
            'discountAmount': widget.orderData!['discountAmount'],
            'totalPrice': widget.orderData!['totalPrice'],
            'amount': widget.orderData!['totalPrice'], // Ajouter cette ligne
            'pickupAddress': widget.orderData!['pickupAddress'],
            'status': 'pending',
            'metadata': widget.metadata,
            'createdAt': FieldValue.serverTimestamp(),
          });
          break;

        case 'express_deal':
          orderId = widget.metadata['reservationId'];
          widget.metadata['orderId'] = orderId;
          successUrlWithParams = '${widget.successUrl}?orderId=$orderId';
          
          await FirebaseFirestore.instance
              .collection('pending_orders')
              .doc(orderId)
              .set({
            'type': 'express_deal',
            'userId': FirebaseAuth.instance.currentUser?.uid,
            'dealId': widget.metadata['dealId'],
            'postId': widget.metadata['postId'],
            'companyId': widget.metadata['companyId'],
            'pickupDate': widget.metadata['pickupDate'],
            'basketType': widget.metadata['basketType'],
            'companyName': widget.metadata['companyName'],
            'pickupAddress': widget.metadata['pickupAddress'],
            'status': 'pending',
            'amount': widget.amount / 100, // S'assurer que c'est défini
            'tva': widget.metadata['tva'],
            'metadata': widget.metadata,
            'createdAt': FieldValue.serverTimestamp(),
          });
          break;

        case 'service':
          orderId = widget.metadata['bookingId'];
          widget.metadata['orderId'] = orderId;
          successUrlWithParams = '${widget.successUrl}?orderId=$orderId';
          
          await FirebaseFirestore.instance
              .collection('pending_orders')
              .doc(orderId)
              .set({
            'type': 'service',
            'userId': FirebaseAuth.instance.currentUser?.uid,
            'serviceId': widget.metadata['serviceId'],
            'serviceName': widget.metadata['serviceName'],
            'bookingDateTime': widget.metadata['bookingDateTime'],
            'professionalId': widget.metadata['professionalId'],
            'duration': widget.metadata['duration'],
            'amount': widget.amount / 100, // S'assurer que c'est défini
            'tva': widget.metadata['tva'],
            'priceTTC': widget.metadata['priceTTC'],
            'priceHT': widget.metadata['priceHT'],
            'adresse': widget.metadata['adresse'],
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'hasPromotion': widget.metadata['hasPromotion'] ?? false,
            'promotionDetails': widget.metadata['promotionDetails'],
            'originalPrice': widget.metadata['originalPrice'],
            'finalPrice': widget.metadata['finalPrice'],
            'discount': widget.metadata['discount'],
            if (widget.metadata['promoCode'] != null) ...<String, dynamic>{
              'promoCode': widget.metadata['promoCode'],
              'promoDiscount': widget.metadata['promoDiscount'],
            },
          });
          break;
      }

      if (!successUrlWithParams.startsWith('http')) {
        throw Exception('URL de redirection invalide: $successUrlWithParams');
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable('createUnifiedPayment')
          .call({
        'type': widget.type,
        'amount': widget.amount,
        'metadata': widget.metadata,
        'successUrl': successUrlWithParams,
        'cancelUrl': widget.cancelUrl,
        'isWeb': kIsWeb,
      });

      if (kIsWeb) {
        final String checkoutUrl = result.data['url'];
        if (!checkoutUrl.startsWith('http')) {
          throw Exception('URL de paiement invalide: $checkoutUrl');
        }
        html.window.location.href = checkoutUrl;
      } else {
        // Version mobile
        try {
          final BuildContext currentContext = context;

          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              merchantDisplayName: 'Up',
              paymentIntentClientSecret: result.data['clientSecret'],
            ),
          );

          await Stripe.instance.presentPaymentSheet();
          await Future.delayed(const Duration(seconds: 3));

          if (mounted) {
            if (context.mounted) {
              await Navigator.of(currentContext).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => UnifiedPaymentSuccessScreen(
                    sessionId: result.data['sessionId'],
                    orderId: orderId,
                  ),
                ),
                (route) => false,
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e')),
            );
          }
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
