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

      // Puis créer la session de paiement
      final result = await FirebaseFunctions.instance
          .httpsCallable('createUnifiedPayment')
          .call({
        'type': widget.type,
        'amount': widget.amount,
        'metadata': widget.metadata,
        'successUrl': widget.successUrl,
        'cancelUrl': widget.cancelUrl,
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
        widget.onSuccess?.call();
        // ... gestion mobile
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
