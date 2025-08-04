import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/services/booking_service.dart';
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
  State<ServicePaymentPage> createState() => _ServicePaymentPageState();
}

class _ServicePaymentPageState extends State<ServicePaymentPage> {
  String? _bookingId;
  String? _promoCode;
  double _finalPrice = 0;
  bool _isLoading = false;
  final TextEditingController _promoCodeController = TextEditingController();
  final BookingService _bookingService = BookingService();
  Map<String, dynamic>? _address;

  @override
  void initState() {
    super.initState();
    _finalPrice = widget.service.finalPrice;
    _generateOrderId();
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

  Future<void> _applyPromoCode() async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final finalPrice = await _bookingService.applyPromoCode(
        code,
        widget.service.professionalId,
        FirebaseAuth.instance.currentUser!.uid,
        widget.service.id,
        widget.service.price,
      );

      setState(() {
        _promoCode = code;
        _finalPrice = finalPrice;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code promo appliqué avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removePromoCode() {
    setState(() {
      _promoCode = null;
      _finalPrice = widget.service.price;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code promo supprimé')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_address == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Déterminer les URLs de redirection en fonction de l'environnement
    final String baseUrl =
        kIsWeb ? Uri.base.origin : 'https://happy-deals.web.app';
    final String successUrl = '$baseUrl/#/payment-success';
    final String cancelUrl = '$baseUrl/#/payment-cancel';

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
                  child: UnifiedPaymentButton(
                    type: 'service',
                    amount: (_finalPrice * 100).round(),
                    metadata: {
                      "bookingId": _bookingId!,
                      "orderId": _bookingId!,
                      'amount': (_finalPrice * 100).round().toString(),
                      'serviceId': widget.service.id,
                      'duration': widget.service.duration,
                      "priceTTC": widget.service.price,
                      "tva": widget.service.tva,
                      "priceHT": widget.service.price /
                          (1 + (widget.service.tva / 100)),
                      'serviceName': widget.service.name,
                      'bookingDateTime':
                          widget.bookingDateTime.toUtc().toIso8601String(),
                      'professionalId': widget.service.professionalId,
                      if (_promoCode != null) ...<String, dynamic>{
                        'promoCode': _promoCode,
                        'originalPrice': widget.service.price,
                        'discountAmount': (widget.service.price - _finalPrice),
                        'finalPrice': _finalPrice,
                        'promoApplied': true,
                      },
                      'adresse':
                          '${_address!['adresse']}, ${_address!['code_postal']} ${_address!['ville']}',
                    },
                    successUrl: successUrl,
                    cancelUrl: cancelUrl,
                  )),
            _buildPromoCodeSection(),
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
              'Prix initial',
              '${widget.service.price.toStringAsFixed(2)} €',
            ),
            if (widget.service.hasActivePromotion)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Promotion (${widget.service.discount!.value}${widget.service.discount!.type == 'percentage' ? '%' : '€'})',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                  Text(
                    '-${(widget.service.price - widget.service.finalPrice).toStringAsFixed(2)} €',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            if (_promoCode != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Code promo ($_promoCode)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _removePromoCode,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '-${(widget.service.finalPrice - _finalPrice).toStringAsFixed(2)} €',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
            ],
            _buildSummaryRow(
              'Total à payer',
              '${_finalPrice.toStringAsFixed(2)} €',
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

  Widget _buildPromoCodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Code promo'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  decoration: const InputDecoration(
                    hintText: 'Entrez votre code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _applyPromoCode,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Appliquer'),
              ),
            ],
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
