import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/details_page/details_reservation_dealexpress_page.dart';
import 'package:intl/intl.dart';

class ReservationListDealExpress extends StatelessWidget {
  const ReservationListDealExpress({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations',
            style: TextStyle(color: Colors.black)),
        elevation: 3,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservations')
            .where('buyerId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aucune réservation trouvée'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final reservation = snapshot.data!.docs[index];
              final data = reservation.data() as Map<String, dynamic>;
              return _buildReservationCard(context, reservation.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildReservationCard(
      BuildContext context, String reservationId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReservationDetailsPage(reservationId: reservationId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    reservationId.substring(0, 6),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildStatusChip(data['isValidated'] ?? false),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('dd/MM/yyyy HH:mm').format((data['timestamp'] as Timestamp).toDate())}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Entreprise: ${data['companyName'] ?? 'Non spécifié'}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Prix: ${(data['price'] ?? 0.0).toStringAsFixed(2)}€',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'À récupérer: ${DateFormat('dd/MM/yyyy HH:mm').format((data['pickupDate'] as Timestamp).toDate())}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isValidated) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: isValidated ? Colors.green : Colors.orange,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 7),
        child: Text(
          isValidated ? 'Validé' : 'En attente',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
