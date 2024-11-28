// lib/pages/services/service_payment_page.dart
import 'dart:html' as html;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/classes/time_slot.dart';
import 'package:intl/intl.dart';

class ServicePaymentPage extends StatefulWidget {
  final ServiceModel service;
  final TimeSlotModel timeSlot;

  const ServicePaymentPage({
    super.key,
    required this.service,
    required this.timeSlot,
  });

  @override
  _ServicePaymentPageState createState() => _ServicePaymentPageState();
}

class _ServicePaymentPageState extends State<ServicePaymentPage> {
  bool _isLoading = false;

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);

    try {
      final functions = FirebaseFunctions.instance;

      // Appeler la Cloud Function pour créer la session de paiement
      final result =
          await functions.httpsCallable('createServicePaymentWeb').call({
        'serviceId': widget.service.id,
        'timeSlotId': widget.timeSlot.id,
        'amount': (widget.service.price * 100).round(),
        'currency': 'eur',
        'successUrl': '${Uri.base.origin}/payment-success',
        'cancelUrl': '${Uri.base.origin}/payment-cancel',
      });

      // Rediriger vers Stripe Checkout
      final sessionUrl = result.data['url'];
      html.window.location.href = sessionUrl;
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummary(),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handlePayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Payer ${widget.service.price.toStringAsFixed(2)} €',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Récapitulatif de la réservation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(
              'Service',
              widget.service.name,
            ),
            _buildSummaryRow(
              'Date',
              DateFormat('dd/MM/yyyy').format(widget.timeSlot.date),
            ),
            _buildSummaryRow(
              'Heure',
              '${DateFormat('HH:mm').format(widget.timeSlot.startTime)} - '
                  '${DateFormat('HH:mm').format(widget.timeSlot.endTime)}',
            ),
            _buildSummaryRow(
              'Durée',
              '${widget.service.duration} minutes',
            ),
            const Divider(height: 32),
            _buildSummaryRow(
              'Total',
              '${widget.service.price.toStringAsFixed(2)} €',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
