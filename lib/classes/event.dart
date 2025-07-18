import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';

class Event extends Post {
  final String title;
  final String searchText;

  final String category;
  final DateTime eventDate;
  final DateTime eventEndDate;
  final String city;
  final String address;
  final String subCategory;
  final double latitude;
  final double longitude;
  final String description;
  final List<String> products;
  final String photo;
  final int maxAttendees;
  final int attendeeCount;

  Event({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.searchText,
    required this.category,
    required this.eventDate,
    required this.eventEndDate,
    required this.city,
    required this.description,
    required super.companyId,
    required this.products,
    required this.photo,
    required this.address,
    required this.subCategory,
    required this.latitude,
    required this.longitude,
    this.maxAttendees = 100, // valeur par défaut
    this.attendeeCount = 0,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    required super.companyName,
    required super.companyLogo,
    super.comments,
  }) : super(
          type: 'event',
        );

  factory Event.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Event(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      title: data['title'],
      searchText: data['searchText'],
      category: data['category'],
      eventDate: (data['eventDate'] as Timestamp).toDate(),
      eventEndDate: (data['eventEndDate'] as Timestamp).toDate(),
      city: data['city'],
      address: data['address'],
      subCategory: data['subCategory'],
      latitude: data['latitude'],
      longitude: data['longitude'],
      description: data['description'],
      companyId: data['companyId'],
      companyName: data['companyName'],
      companyLogo: data['companyLogo'],
      products: List<String>.from(data['products']),
      photo: data['photo'],
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      maxAttendees: data['maxAttendees'] ?? 100,
      attendeeCount: data['attendeeCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'searchText': searchText,
      'category': category,
      'eventDate': Timestamp.fromDate(eventDate),
      'eventEndDate': Timestamp.fromDate(eventEndDate),
      'city': city,
      'description': description,
      'products': products,
      'photo': photo,
      'companyId': companyId,
      'maxAttendees': maxAttendees,
      'attendeeCount': attendeeCount,
      'address': address,
      'subCategory': subCategory,
      'latitude': latitude,
      'longitude': longitude,
    });
    return map;
  }
}

class Attendee {
  final String userId;
  final DateTime registrationDate;
  final String eventId;
  final int ticketCount;

  Attendee({
    required this.userId,
    required this.registrationDate,
    required this.eventId,
    required this.ticketCount,
  });

  factory Attendee.fromMap(Map<String, dynamic> data) {
    return Attendee(
      userId: data['userId'],
      registrationDate: (data['registrationDate'] as Timestamp).toDate(),
      eventId: data['eventId'],
      ticketCount: data['ticketCount'],
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'registrationDate': Timestamp.fromDate(registrationDate),
        'eventId': eventId,
        'ticketCount': ticketCount,
      };
}

class AttendanceDialog extends StatefulWidget {
  final Event event;
  final String userId;

  const AttendanceDialog({
    required this.event,
    required this.userId,
    super.key,
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  int _currentStep = 0;
  int _ticketCount = 1;
  bool _acceptedConditions = false;

  Future<void> _register() async {
    try {
      debugPrint("Début de l'inscription");

      final attendee = Attendee(
        userId: widget.userId,
        registrationDate: DateTime.now(),
        eventId: widget.event.id,
        ticketCount: _ticketCount,
      );

      // Vérification de l'événement
      final eventRef =
          FirebaseFirestore.instance.collection('posts').doc(widget.event.id);
      final eventDoc = await eventRef.get();

      if (!eventDoc.exists) {
        throw 'Événement introuvable';
      }

      if (DateTime.now().isAfter(widget.event.eventDate)) {
        throw 'L\'événement est terminé';
      }

      debugPrint("Ajout du participant");

      // Ajout simple du participant
      await eventRef.collection('attendees').add(attendee.toMap());

      debugPrint("Mise à jour du compteur");

      // Mise à jour du compteur
      await eventRef
          .update({'attendeeCount': FieldValue.increment(_ticketCount)});

      debugPrint("Inscription terminée avec succès");

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inscription confirmée !')),
        );
      }
    } catch (e) {
      debugPrint("Erreur lors de l'inscription: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep == 0 && !_acceptedConditions) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Veuillez accepter les conditions')),
              );
              return;
            }

            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _register();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
          steps: [
            Step(
              title: const Text('Conditions'),
              content: Column(
                children: [
                  const Text('Conditions de participation à l\'événement...'),
                  CheckboxListTile(
                    value: _acceptedConditions,
                    onChanged: (value) =>
                        setState(() => _acceptedConditions = value!),
                    title: const Text('J\'accepte les conditions'),
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Tickets'),
              content: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() {
                      if (_ticketCount > 1) _ticketCount--;
                    }),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$_ticketCount ticket(s)'),
                  IconButton(
                    onPressed: () => setState(() => _ticketCount++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Confirmation'),
              content: Text(
                  'Confirmez-vous votre inscription pour $_ticketCount ticket(s) ?'),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
    );
  }
}
