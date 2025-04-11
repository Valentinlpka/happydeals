import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/widgets/unified_payment_button.dart';
import 'package:intl/intl.dart';

class ReservationScreen extends StatefulWidget {
  final ExpressDeal deal;
  final DateTime selectedPickupTime;

  const ReservationScreen({
    super.key,
    required this.deal,
    required this.selectedPickupTime,
  });

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  String? _reservationId; // Ajoutez cette ligne

  String? companyName;
  String? companyAddress;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCompanyDetails();
    _generateReservationId(); // Ajoutez cette ligne
  }

  Future<void> _generateReservationId() async {
    // Créer une référence de document vide dans la collection 'orders'
    final reservationRef =
        FirebaseFirestore.instance.collection('reservations').doc();
    setState(() {
      _reservationId = reservationRef.id;
    });
  }

  Future<void> _fetchCompanyDetails() async {
    try {
      setState(() => isLoading = true);

      final companyDoc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(widget.deal.companyId)
          .get();

      if (companyDoc.exists) {
        final data = companyDoc.data() as Map<String, dynamic>;
        setState(() {
          companyName = data['name'] as String?;
          final address = data['adress'] as Map<String, dynamic>?;
          if (address != null) {
            companyAddress =
                '${address['adresse']}, ${address['code_postal']} ${address['ville']}';
          }
        });
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Réservation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(context),
                      const SizedBox(height: 50),
                      _buildTotalSection(context),
                      if (widget.deal.availableBaskets <= 3)
                        _buildAvailabilityWarning(),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: UnifiedPaymentButton(
            type: 'express_deal',
            amount: widget.deal.price * 100, // Convertir en centimes
            metadata: {
              'reservationId': _reservationId,
              'price': widget.deal.price,
              'tva': widget.deal.tva,
              'basketType': widget.deal.basketType,
              'quantity': '1',
              'postId': widget.deal.id,
              'title': widget.deal.title,
              'content': widget.deal.content,
              'pickupDate': widget.selectedPickupTime.toIso8601String(),
              'companyId': widget.deal.companyId,
              'stripeAccountId': widget.deal.stripeAccountId,
              'basketCount': widget.deal.basketCount,
              'availableBaskets': widget.deal.availableBaskets,
              'companyName': companyName,
              'pickupAddress': companyAddress,
              'timestamp': widget.deal.timestamp.toIso8601String(),
            },
            successUrl:
                '${kIsWeb ? Uri.base.origin : 'https://happy-deals.web.app'}/#/payment-success?reservationId=$_reservationId',
            cancelUrl:
                '${kIsWeb ? Uri.base.origin : 'https://happy-deals.web.app'}/#/payment-cancel',
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (companyName ?? "Nom de l'entreprise non disponible"),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 15),
        _buildInfoRow(Icons.shopping_bag_outlined, widget.deal.title),
        _buildInfoRow(Icons.description_outlined, widget.deal.content),
        const SizedBox(height: 10),
        _buildInfoRow(
          Icons.access_time,
          'À récupérer le ${DateFormat('dd/MM/yyyy à HH:mm').format(widget.selectedPickupTime)}',
        ),
        _buildInfoRow(
          Icons.location_on,
          companyAddress ?? 'Adresse non disponible',
        ),
        _buildInfoRow(
          Icons.inventory_2_outlined,
          'Paniers disponibles: ${widget.deal.availableBaskets}',
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '${widget.deal.price.toStringAsFixed(2)} €',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityWarning() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Plus que ${widget.deal.availableBaskets} panier${widget.deal.availableBaskets > 1 ? 's' : ''} disponible${widget.deal.availableBaskets > 1 ? 's' : ''}!',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
