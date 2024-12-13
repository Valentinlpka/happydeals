import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/widgets/cards/evenement_card.dart';

class MyEventsPage extends StatelessWidget {
  final String userId;

  const MyEventsPage({
    required this.userId,
    super.key,
  });

  Future<List<Event>> _fetchMyEvents() async {
    try {
      print("Début de la requête pour userId: $userId");

      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('attendees')
          .where('userId', isEqualTo: userId)
          .get()
          .then((value) {
        print("Résultat de la requête: ${value.docs.length} documents");
        return value;
      }).catchError((error) {
        print("Erreur détaillée de la requête: $error");
        print("Stack trace de l'erreur: ${StackTrace.current}");
        throw error;
      });

      print("Documents trouvés: ${querySnapshot.docs.length}");

      List<Event> events = [];

      for (var doc in querySnapshot.docs) {
        print("Document attendee ID: ${doc.id}");
        print("Chemin complet: ${doc.reference.path}");

        final eventId = doc.reference.parent.parent!.id;
        print("ID de l'événement parent: $eventId");

        try {
          final eventDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(eventId)
              .get();

          print("Document événement trouvé: ${eventDoc.exists}");

          if (eventDoc.exists) {
            events.add(Event.fromDocument(eventDoc));
            print("Événement ajouté à la liste: ${eventDoc.id}");
          }
        } catch (e) {
          print("Erreur lors de la récupération de l'événement $eventId: $e");
        }
      }

      print("Nombre total d'événements récupérés: ${events.length}");
      return events;
    } catch (e, stackTrace) {
      print("Erreur globale: $e");
      print("Stack trace: $stackTrace");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes événements'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<Event>>(
        future: _fetchMyEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty) {
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
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return EvenementCard(
                event: event,
                currentUserId: userId,
              );
            },
          );
        },
      ),
    );
  }
}
