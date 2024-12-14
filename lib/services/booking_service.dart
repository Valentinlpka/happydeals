import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/availibility_rule.dart';
import 'package:happy/classes/booking.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupérer les créneaux disponibles pour un service
  Stream<List<AvailabilityRuleModel>> getServiceAvailabilityRules(
      String serviceId) {
    return _firestore
        .collection('availabilityRules')
        .where('serviceId', isEqualTo: serviceId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AvailabilityRuleModel.fromMap(doc.data()))
            .toList());
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
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromFirestore(doc))
            .toList());
  }

  List<DateTime> generateTimeSlotsForDay(
    AvailabilityRuleModel rule,
    DateTime date,
    int serviceDuration,
  ) {
    final List<DateTime> slots = [];
    final now = DateTime.now();

    // Créer le premier créneau de la journée
    var currentSlot = DateTime(
      date.year,
      date.month,
      date.day,
      rule.startTime.hours,
      rule.startTime.minutes,
    );

    final endTime = DateTime(
      date.year,
      date.month,
      date.day,
      rule.endTime.hours,
      rule.endTime.minutes,
    );

    // Si la date est dans le passé, retourner une liste vide
    if (date.year == now.year &&
        date.month == now.month &&
        date.day < now.day) {
      return [];
    }

    while (
        currentSlot.add(Duration(minutes: serviceDuration)).isBefore(endTime) ||
            currentSlot.add(Duration(minutes: serviceDuration)) == endTime) {
      // Pour aujourd'hui, ignorer les créneaux passés
      if (date.day == now.day && currentSlot.isBefore(now)) {
        currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
        continue;
      }

      slots.add(currentSlot);
      currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
    }

    return slots;
  }

  Future<List<DateTime>> getAvailableTimeSlots(
      String serviceId, DateTime date, int duration) async {
    try {
      final rules = await getServiceAvailabilityRules(serviceId).first;
      if (rules.isEmpty) return [];

      final rule = rules.first;
      if (!rule.workDays.contains(date.weekday)) return [];

      final slots = generateTimeSlotsForDay(rule, date, duration);
      List<DateTime> availableSlots = [];

      for (var slot in slots) {
        final slotMinutes = slot.hour * 60 + slot.minute;
        final startMinutes = rule.startTime.hours * 60 + rule.startTime.minutes;
        final endMinutes = rule.endTime.hours * 60 + rule.endTime.minutes;

        if (slotMinutes >= startMinutes && slotMinutes < endMinutes) {
          // Vérifier les réservations existantes
          final bookings = await _firestore
              .collection('bookings')
              .where('serviceId', isEqualTo: serviceId)
              .where('bookingDateTime', isEqualTo: Timestamp.fromDate(slot))
              .where('status', whereIn: ['confirmed', 'pending']).get();

          if (bookings.docs.isEmpty) {
            availableSlots.add(slot);
          }
        }
      }

      return availableSlots;
    } catch (e) {
      return [];
    }
  }
}
