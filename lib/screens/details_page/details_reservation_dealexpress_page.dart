import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReservationDetailsPage extends StatelessWidget {
  final String reservationId;

  const ReservationDetailsPage({Key? key, required this.reservationId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détails de la Réservation')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reservations')
            .doc(reservationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Réservation introuvable'));
          }
          final reservation = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Acheteur: ${reservation['buyerId']}'),
                Text('Quantité: ${reservation['quantity']}'),
                Text('Prix: ${reservation['price']}'),
                Text(
                    'Date de récupération: ${reservation['pickupDate'].toDate()}'),
                Text('Post ID: ${reservation['postId']}'),
              ],
            ),
          );
        },
      ),
    );
  }
}
