import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/cards/evenement_card.dart';

class MyEventsPage extends StatelessWidget {
  final String userId;

  const MyEventsPage({
    required this.userId,
    super.key,
  });

  Future<List<Map<String, dynamic>>> _fetchMyEventsWithCompanyData() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('attendees')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> eventsWithCompany = [];

      for (var doc in querySnapshot.docs) {
        try {
          final eventId = doc.reference.parent.parent!.id;

          // Récupérer l'événement
          final eventDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(eventId)
              .get();

          if (eventDoc.exists) {
            final event = Event.fromDocument(eventDoc);

            // Récupérer les données de l'entreprise
            final companyDoc = await FirebaseFirestore.instance
                .collection('companys')
                .doc(event.companyId)
                .get();

            if (companyDoc.exists) {
              eventsWithCompany.add({
                'event': event,
                'companyName': companyDoc.data()?['name'] ?? '',
                'companyLogo': companyDoc.data()?['logo'] ?? '',
              });
            }
          }
        } catch (e) {
          debugPrint(e.toString());
        }
      }

      return eventsWithCompany;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        align: Alignment.center,
        title: 'Mes événements',
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchMyEventsWithCompanyData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final eventsWithCompany = snapshot.data ?? [];

          if (eventsWithCompany.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Vous n\'êtes inscrit à aucun événement',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: eventsWithCompany.length,
            itemBuilder: (context, index) {
              final eventData = eventsWithCompany[index];
              return EvenementCard(
                event: eventData['event'] as Event,
                currentUserId: userId,
              );
            },
          );
        },
      ),
    );
  }
}
