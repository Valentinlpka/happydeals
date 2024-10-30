import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';

class ReservationDetailsPage extends StatefulWidget {
  final String reservationId;

  const ReservationDetailsPage({super.key, required this.reservationId});

  @override
  _ReservationDetailsPageState createState() => _ReservationDetailsPageState();
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
      appBar: const CustomAppBarBack(title: 'Détails de la réservation'),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _reservationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          } else if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Réservation non trouvée'));
          }

          final reservation = snapshot.data!.data() as Map<String, dynamic>;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReservationHeader(reservation),
                  _buildReservationStatus(reservation),
                  _buildValidationCode(reservation),
                  _buildPickupInfo(reservation),
                  _buildReservationDetails(reservation),
                  _buildReservationSummary(reservation),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(width: 0.4, color: Colors.black26)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
              onPressed: () async {
                final reservation = await FirebaseFirestore.instance
                    .collection('reservations')
                    .doc(widget.reservationId)
                    .get();
                final address = reservation.data()?['pickupAddress'] as String?;
                if (address != null) {
                  await MapsLauncher.launchQuery(address);
                }
              },
              child: const Text("S'y rendre"),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReservationHeader(Map<String, dynamic> reservation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Réservation #${widget.reservationId.substring(0, 8)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Passée le ${DateFormat('dd/MM/yyyy à HH:mm').format((reservation['timestamp'] as Timestamp).toDate())}',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationStatus(Map<String, dynamic> reservation) {
    final status = reservation['status'] as String? ?? 'En attente';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Statut de la réservation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_getStatusIcon(status), color: _getStatusColor(status)),
              const SizedBox(width: 8),
              Text(
                _getStatusText(status),
                style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationCode(Map<String, dynamic> reservation) {
    final validationCode = reservation['validationCode'] as String?;
    if (validationCode == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Code de validation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            validationCode,
            style: const TextStyle(fontSize: 18, letterSpacing: 5),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupInfo(Map<String, dynamic> reservation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations de retrait',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Adresse: ${reservation['pickupAddress'] ?? 'Non spécifiée'}'),
          const SizedBox(height: 8),
          Text(
              'Date: ${DateFormat('dd/MM/yyyy à HH:mm').format((reservation['pickupDate'] as Timestamp).toDate())}'),
        ],
      ),
    );
  }

  Widget _buildReservationDetails(Map<String, dynamic> reservation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Détails de la réservation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDetailRow(
              'Type de panier', reservation['basketType'] ?? 'Non spécifié'),
          _buildDetailRow('Quantité', '${reservation['quantity'] ?? 1}'),
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
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReservationSummary(Map<String, dynamic> reservation) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Récapitulatif',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total'),
              Text('${reservation['price']?.toStringAsFixed(2) ?? '0.00'}€',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmé':
        return Icons.check_circle;
      case 'en attente':
        return Icons.hourglass_empty;
      case 'annulé':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmé':
        return Colors.green;
      case 'en attente':
        return Colors.orange;
      case 'annulé':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    return status.capitalize();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
