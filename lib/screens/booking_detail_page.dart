import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';

class BookingDetailPage extends StatefulWidget {
  final String bookingId;

  const BookingDetailPage({super.key, required this.bookingId});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Future<DocumentSnapshot> _bookingFuture;
  late Future<DocumentSnapshot> _serviceFuture;

  @override
  void initState() {
    super.initState();
    // Ajout d'une vérification de l'ID
    if (widget.bookingId.isEmpty) {
      throw ArgumentError('bookingId cannot be empty');
    }

    print('Booking ID: ${widget.bookingId}'); // Pour debug
    _bookingFuture =
        _firestore.collection('bookings').doc(widget.bookingId).get();
    _serviceFuture = _bookingFuture.then((bookingDoc) {
      String serviceId = bookingDoc['serviceId'];
      return _firestore.collection('services').doc(serviceId).get();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la réservation'),
      ),
      bottomNavigationBar: FutureBuilder<DocumentSnapshot>(
        future: _bookingFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          final data = snapshot.data!.data() as Map<String, dynamic>;
          return _buildBottomBar(data);
        },
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: Future.wait([_bookingFuture, _serviceFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Réservation non trouvée'));
          }

          final bookingData = snapshot.data![0].data() as Map<String, dynamic>;
          final serviceData = snapshot.data![1].data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBookingHeader(bookingData),
                const SizedBox(height: 20),
                _buildServiceDetails(serviceData),
                const SizedBox(height: 20),
                _buildDateTimeInfo(bookingData),
                const SizedBox(height: 20),
                _buildStatusSection(bookingData),
                const SizedBox(height: 20),
                _buildPriceSection(bookingData),
                if (bookingData['professionalNotes'] != null) ...[
                  const SizedBox(height: 20),
                  _buildProfessionalNotes(bookingData['professionalNotes']),
                ],
                const SizedBox(height: 20),
                _buildLocationInfo(bookingData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic> bookingData) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  MapsLauncher.launchQuery(bookingData['address']);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('S\'y rendre'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingHeader(Map<String, dynamic> bookingData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Réservation #${widget.bookingId.substring(0, 8)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Réservé le ${DateFormat('dd/MM/yyyy à HH:mm').format(bookingData['createdAt'].toDate())}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDetails(Map<String, dynamic> serviceData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service réservé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(serviceData['name']),
            Text('Durée: ${serviceData['duration']} minutes'),
            if (serviceData['description'] != null)
              Text(serviceData['description']),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeInfo(Map<String, dynamic> bookingData) {
    DateTime bookingDateTime =
        (bookingData['bookingDateTime'] as Timestamp).toDate();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date et heure',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Date: ${DateFormat('dd/MM/yyyy').format(bookingDateTime)}'),
            Text('Heure: ${DateFormat('HH:mm').format(bookingDateTime)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(Map<String, dynamic> bookingData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statut',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _getStatusIcon(bookingData['status']),
                  color: _getStatusColor(bookingData['status']),
                ),
                const SizedBox(width: 8),
                Text(
                  _getStatusText(bookingData['status']),
                  style: TextStyle(
                    color: _getStatusColor(bookingData['status']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSection(Map<String, dynamic> bookingData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paiement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total payé'),
                Text('${(bookingData['amount'] / 100).toStringAsFixed(2)}€'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(Map<String, dynamic> bookingData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lieu du rendez-vous',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(bookingData['adresse'] ?? 'Adresse non disponible'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalNotes(String notes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes du professionnel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(notes),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmé';
      case 'pending':
        return 'En attente';
      case 'cancelled':
        return 'Annulé';
      default:
        return 'Inconnu';
    }
  }
}
