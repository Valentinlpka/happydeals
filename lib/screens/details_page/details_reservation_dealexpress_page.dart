import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';

class ReservationDetailsPage extends StatefulWidget {
  final String reservationId;
  const ReservationDetailsPage({super.key, required this.reservationId});

  @override
  State<ReservationDetailsPage> createState() => _ReservationDetailsPageState();
}

class _ReservationDetailsPageState extends State<ReservationDetailsPage> {
  late Stream<DocumentSnapshot> _reservationStream;

  @override
  void initState() {
    super.initState();
    _reservationStream = FirebaseFirestore.instance
        .collection('reservations')
        .doc(widget.reservationId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<DocumentSnapshot>(
          stream: _reservationStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const CustomAppBar(title: '', align: Alignment.centerLeft);
            }
            return CustomAppBar(
              title: 'Réservation #${widget.reservationId.substring(0, 8)}',
              align: Alignment.center,
              actions: [
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (route) => false),
                  tooltip: 'Retour à l\'accueil',
                ),
              ],
            );
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _reservationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState();
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildNotFoundState();
          }

          final reservation = snapshot.data!.data() as Map<String, dynamic>;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStatusBanner(reservation),
                const SizedBox(height: 24),
                _buildValidationSection(reservation),
                const SizedBox(height: 24),
                _buildBasketSection(reservation),
                const SizedBox(height: 24),
                _buildPickupSection(reservation),
                const SizedBox(height: 24),
                _buildPriceSection(reservation),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _buildNavigationFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatusBanner(Map<String, dynamic> reservation) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _getStatusColor(reservation['status']).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(reservation['status']).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(reservation['status']),
              color: _getStatusColor(reservation['status']),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statut',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                _getStatusText(reservation['status']),
                style: TextStyle(
                  color: _getStatusColor(reservation['status']),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationSection(Map<String, dynamic> reservation) {
    return _buildSection(
      title: 'Code de validation',
      icon: Icons.key,
      child: Column(
        children: [
          Text(
            reservation['validationCode'],
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'À présenter lors du retrait',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBasketSection(Map<String, dynamic> reservation) {
    return _buildSection(
      title: 'Détails du panier',
      icon: Icons.shopping_basket,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Type de panier', reservation['basketType']),
          _buildDetailRow('Quantité', '${reservation['quantity']}'),
          if (reservation['companyName'] != null)
            _buildDetailRow('Commerce', reservation['companyName']),
        ],
      ),
    );
  }

  Widget _buildPickupSection(Map<String, dynamic> reservation) {
    final pickupDate = (reservation['pickupDate'] as Timestamp).toDate();
    return _buildSection(
      title: 'Informations de retrait',
      icon: Icons.access_time,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            'Date',
            DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(pickupDate),
          ),
          _buildDetailRow('Heure', DateFormat('HH:mm').format(pickupDate)),
          _buildDetailRow('Adresse', reservation['pickupAddress']),
        ],
      ),
    );
  }

  Widget _buildPriceSection(Map<String, dynamic> reservation) {
    return _buildSection(
      title: 'Paiement',
      icon: Icons.payment,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total payé'),
          Text(
            '${reservation['price'].toStringAsFixed(2)}€',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue[800]),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNavigationFAB() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      child: StreamBuilder<DocumentSnapshot>(
        stream: _reservationStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final reservation = snapshot.data!.data() as Map<String, dynamic>;

          return ElevatedButton.icon(
            icon: const Icon(Icons.directions),
            label: const Text("S'y rendre"),
            onPressed: () =>
                MapsLauncher.launchQuery(reservation['pickupAddress']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Une erreur est survenue',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Réservation non trouvée',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.task_alt;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'prête à être retirée':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmé';
      case 'prête à être retirée':
        return 'Prête à être retirée';
      case 'cancelled':
        return 'Annulé';
      case 'completed':
        return 'Terminé';
      default:
        return 'Inconnu';
    }
  }
}
