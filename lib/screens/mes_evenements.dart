import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/widgets/cards/evenement_card.dart';
import 'package:happy/widgets/custom_app_bar.dart';

class MyEventsPage extends StatelessWidget {
  final String userId;

  const MyEventsPage({
    required this.userId,
    super.key,
  });

  Future<List<Map<String, dynamic>>> _fetchMyEventsWithCompanyData() async {
    try {
      print("Début de la requête pour userId: $userId");
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('attendees')
          .where('userId', isEqualTo: userId)
          .get();

      print("Documents trouvés: ${querySnapshot.docs.length}");
      List<Map<String, dynamic>> eventsWithCompany = [];

      for (var doc in querySnapshot.docs) {
        try {
          final eventId = doc.reference.parent.parent!.id;
          print("ID de l'événement parent: $eventId");

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
              print("Événement et données entreprise ajoutés: ${eventDoc.id}");
            }
          }
        } catch (e) {
          print("Erreur lors de la récupération des données: $e");
        }
      }

      print("Nombre total d'événements récupérés: ${eventsWithCompany.length}");
      return eventsWithCompany;
    } catch (e, stackTrace) {
      print("Erreur globale: $e");
      print("Stack trace: $stackTrace");
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
                companyName: eventData['companyName'] as String,
                companyLogo: eventData['companyLogo'] as String,
              );
            },
          );
        },
      ),
    );
  }
}
