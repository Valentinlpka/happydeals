import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/booking.dart';
import 'package:happy/classes/time_slot.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupérer les créneaux disponibles pour un service
  Stream<List<TimeSlotModel>> getAvailableTimeSlots(String serviceId) {
    return _firestore
        .collection('timeSlots')
        .where('serviceId', isEqualTo: serviceId)
        .where('isAvailable', isEqualTo: true)
        .where('date', isGreaterThanOrEqualTo: DateTime.now())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimeSlotModel.fromMap(doc.data()))
            .toList());
  }

  // Créer une nouvelle réservation
  Future<BookingModel> createBooking({
    required String userId,
    required String serviceId,
    required String professionalId,
    required String timeSlotId,
    required double price,
  }) async {
    try {
      // Commencer une transaction
      return await _firestore.runTransaction<BookingModel>((transaction) async {
        // Vérifier que le créneau est toujours disponible
        final timeSlotDoc = await transaction
            .get(_firestore.collection('timeSlots').doc(timeSlotId));

        if (!timeSlotDoc.exists || !timeSlotDoc.data()!['isAvailable']) {
          throw Exception('Ce créneau n\'est plus disponible');
        }

        // Créer la réservation
        final bookingRef = _firestore.collection('bookings').doc();
        final booking = BookingModel(
          id: bookingRef.id,
          userId: userId,
          serviceId: serviceId,
          professionalId: professionalId,
          timeSlotId: timeSlotId,
          bookingDate: DateTime.now(),
          price: price,
          status: 'pending',
          createdAt: DateTime.now(),
        );

        // Mettre à jour le créneau
        transaction.update(
          _firestore.collection('timeSlots').doc(timeSlotId),
          {
            'isAvailable': false,
            'bookedByUserId': userId,
          },
        );

        // Sauvegarder la réservation
        transaction.set(bookingRef, booking.toMap());

        return booking;
      });
    } catch (e) {
      throw Exception('Erreur lors de la réservation: $e');
    }
  }

  // Annuler une réservation
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final bookingDoc = await transaction
            .get(_firestore.collection('bookings').doc(bookingId));

        if (!bookingDoc.exists) {
          throw Exception('Réservation non trouvée');
        }

        // Libérer le créneau
        final timeSlotId = bookingDoc.data()!['timeSlotId'];
        transaction.update(
          _firestore.collection('timeSlots').doc(timeSlotId),
          {
            'isAvailable': true,
            'bookedByUserId': null,
          },
        );

        // Mettre à jour le statut de la réservation
        transaction.update(
          _firestore.collection('bookings').doc(bookingId),
          {
            'status': 'cancelled',
            'updatedAt': DateTime.now(),
          },
        );
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'annulation: $e');
    }
  }

  // Récupérer les réservations d'un utilisateur
  Stream<List<BookingModel>> getUserBookings(String userId) {
    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data()))
            .toList());
  }
}
