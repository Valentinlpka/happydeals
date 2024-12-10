import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/widgets/unified_payment_button.dart';
import 'package:intl/intl.dart';

class ServicePaymentPage extends StatefulWidget {
  final ServiceModel service;
  final DateTime bookingDateTime; // Au lieu de TimeSlotModel

  const ServicePaymentPage({
    super.key,
    required this.service,
    required this.bookingDateTime,
  });

  @override
  _ServicePaymentPageState createState() => _ServicePaymentPageState();
}

class _ServicePaymentPageState extends State<ServicePaymentPage> {
  String? _bookingId; // Ajoutez cette ligne

  final bool _isLoading = false;
  Map<String, dynamic>? _address;

  @override
  void initState() {
    super.initState();
    _generateOrderId(); // Ajoutez cette ligne
    _fetchCompanyAddress();
  }

  Future<void> _fetchCompanyAddress() async {
    final companyDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(widget.service.professionalId)
        .get();

    if (companyDoc.exists) {
      setState(() {
        _address = companyDoc.data()?['adress'] as Map<String, dynamic>;
      });
    }
  }

  Future<void> _generateOrderId() async {
    // Créer une référence de document vide dans la collection 'orders'
    final bookingRef = FirebaseFirestore.instance.collection('bookings').doc();
    setState(() {
      _bookingId = bookingRef.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_address == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
                  child: // Dans ServicePaymentPage
                      UnifiedPaymentButton(
                    type: 'service',
                    amount: (widget.service.price * 100).round(),
                    metadata: {
                      "bookingId": _bookingId!,
                      'amount': (widget.service.price * 100).round().toString(),
                      'serviceId': widget.service.id,
                      'duration': widget.service.duration,
                      'serviceName': widget.service.name,
                      'bookingDateTime': widget.bookingDateTime
                          .toUtc()
                          .toIso8601String(), // Conversion en UTC
                      'professionalId': widget.service.professionalId,
                      'adresse':
                          '${_address!['adresse']}, ${_address!['code_postal']} ${_address!['ville']}',
                    },
                    successUrl: '${Uri.base.origin}/#/payment-success',
                    cancelUrl: '${Uri.base.origin}/payment-cancel',
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    final endTime =
        widget.bookingDateTime.add(Duration(minutes: widget.service.duration));

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
              DateFormat('dd/MM/yyyy').format(widget.bookingDateTime),
            ),
            _buildSummaryRow(
              'Heure',
              '${DateFormat('HH:mm').format(widget.bookingDateTime)} - '
                  '${DateFormat('HH:mm').format(endTime)}',
            ),
            _buildSummaryRow(
              'Adresse',
              '${_address!['adresse']}\n${_address!['code_postal']} ${_address!['ville']}',
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
