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
      String? pendingId;
      String successUrlWithParams = widget.successUrl;

      switch (widget.type) {
        case 'order':
          pendingId =
              FirebaseFirestore.instance.collection('pending_orders').doc().id;
          widget.metadata['orderId'] = pendingId;
          successUrlWithParams = '${widget.successUrl}?orderId=$pendingId';

          await FirebaseFirestore.instance
              .collection('pending_orders')
              .doc(pendingId)
              .set({
            'userId': FirebaseAuth.instance.currentUser?.uid,
            'items': widget.orderData!['items'],
            'sellerId': widget.orderData!['sellerId'],
            'entrepriseId': widget.orderData!['entrepriseId'],
            'subtotal': widget.orderData!['subtotal'],
            'promoCode': widget.orderData!['promoCode'],
            'discountAmount': widget.orderData!['discountAmount'],
            'totalPrice': widget.orderData!['totalPrice'],
            'pickupAddress': widget.orderData!['pickupAddress'],
            'status': 'pending',
            'metadata': widget.metadata,
            'createdAt': FieldValue.serverTimestamp(),
          });
          break;

        case 'express_deal':
          pendingId = widget.metadata['reservationId'];
          successUrlWithParams =
              '${widget.successUrl}?reservationId=$pendingId';
          break;

        case 'service':
          pendingId = widget.metadata['bookingId'];
          successUrlWithParams = '${widget.successUrl}?bookingId=$pendingId';
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
        html.window.location.href = checkoutUrl;
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            merchantDisplayName: 'Happy Deals',
            paymentIntentClientSecret: result.data['clientSecret'],
          ),
        );

        await Stripe.instance.presentPaymentSheet();

        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UnifiedPaymentSuccessScreen(
                sessionId: result.data['sessionId'],
              ),
            ),
          );
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
