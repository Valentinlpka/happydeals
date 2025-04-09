import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:intl/date_symbol_data_local.dart';
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
    initializeDateFormatting('fr_FR', null); // Ajouter cette ligne

    if (widget.bookingId.isEmpty) {
      throw ArgumentError('bookingId cannot be empty');
    }
    _bookingFuture =
        _firestore.collection('bookings').doc(widget.bookingId).get();
    _serviceFuture = _bookingFuture.then((bookingDoc) {
      return _firestore
          .collection('services')
          .doc(bookingDoc['serviceId'])
          .get();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait([_bookingFuture, _serviceFuture]),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const CustomAppBar(title: '', align: Alignment.centerLeft);

            return CustomAppBar(
              title: 'Réservation #${widget.bookingId.substring(0, 8)}',
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
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: Future.wait([_bookingFuture, _serviceFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          if (!snapshot.hasData) {
            return _buildNotFoundState();
          }

          final bookingData = snapshot.data![0].data() as Map<String, dynamic>;
          final serviceData = snapshot.data![1].data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildStatusBanner(bookingData),
                const SizedBox(height: 24),
                _buildServiceSection(serviceData),
                const SizedBox(height: 24),
                _buildDateTimeSection(bookingData),
                const SizedBox(height: 24),
                _buildPriceSection(bookingData),
                if (bookingData['professionalNotes'] != null) ...[
                  const SizedBox(height: 24),
                  _buildNotesSection(bookingData['professionalNotes']),
                ],
                const SizedBox(height: 24),
                _buildLocationSection(bookingData),
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

  Widget _buildStatusBanner(Map<String, dynamic> bookingData) {
    final status = bookingData['status'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(status),
              color: _getStatusColor(status),
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
                _getStatusText(status),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSection(Map<String, dynamic> serviceData) {
    return _buildSection(
      title: 'Service réservé',
      icon: Icons.spa,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serviceData['name'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '${serviceData['duration']} minutes',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          if (serviceData['description'] != null) ...[
            const SizedBox(height: 8),
            Text(
              serviceData['description'],
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateTimeSection(Map<String, dynamic> bookingData) {
    final DateTime bookingDateTime =
        (bookingData['bookingDateTime'] as Timestamp).toDate();
    return _buildSection(
      title: 'Date et heure',
      icon: Icons.calendar_today,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                      .format(bookingDateTime)
                      .replaceFirst(
                        bookingDateTime.day.toString(),
                        '${bookingDateTime.day}',
                      ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(bookingDateTime),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
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

  Widget _buildPriceSection(Map<String, dynamic> bookingData) {
    return _buildSection(
      title: 'Paiement',
      icon: Icons.payment,
      child: Column(
        children: [
          if (bookingData['promoCode'] != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Prix initial'),
                Text(
                  '${(bookingData['originalPrice']).toStringAsFixed(2)}€',
                  style: TextStyle(
                    color: Colors.grey[600],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code promo (${bookingData['promoCode']})',
                  style: TextStyle(color: Colors.green[700]),
                ),
                Text(
                  '-${(bookingData['discountAmount']).toStringAsFixed(2)}€',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total payé'),
              Text(
                '${(bookingData['finalPrice'] ?? bookingData['amount'] / 100).toStringAsFixed(2)}€',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(Map<String, dynamic> bookingData) {
    return _buildSection(
      title: 'Lieu du rendez-vous',
      icon: Icons.location_on,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bookingData['adresse'] ?? 'Adresse non disponible',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(String notes) {
    return _buildSection(
      title: 'Notes du professionnel',
      icon: Icons.note,
      child: Text(notes),
    );
  }

  Widget _buildNavigationFAB() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<DocumentSnapshot>(
        future: _bookingFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();

          final bookingData = snapshot.data!.data() as Map<String, dynamic>;
          final address = bookingData['adresse'] as String;

          return ElevatedButton(
            onPressed: () {
              MapsLauncher.launchQuery(address);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions),
                SizedBox(width: 8),
                Text('S\'y rendre'),
              ],
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
      case 'completed':
        return Colors.blue;
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
      case 'completed':
        return 'Terminée';
      default:
        return 'Inconnu';
    }
  }
}
