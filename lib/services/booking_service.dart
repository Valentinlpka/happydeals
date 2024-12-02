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

// Dans BookingService
  Future<bool> isTimeSlotAvailable(String serviceId, DateTime dateTime) async {
    try {
      final rules = await getServiceAvailabilityRules(serviceId).first;
      if (rules.isEmpty) return false;

      final rule = rules.first;

      // 1. Vérification du jour de travail
      if (!rule.workDays.contains(dateTime.weekday)) {
        return false;
      }

      // 2. Vérification si la date est dans le passé
      if (dateTime.isBefore(DateTime.now())) {
        return false;
      }

      // 3. Vérification de l'heure d'ouverture
      final slotMinutes = dateTime.hour * 60 + dateTime.minute;
      final startMinutes = rule.startTime.hours * 60 + rule.startTime.minutes;
      final endMinutes = rule.endTime.hours * 60 + rule.endTime.minutes;

      if (slotMinutes < startMinutes || slotMinutes >= endMinutes) {
        return false;
      }

      // 4. Vérification s'il y a déjà une réservation
      try {
        final bookings = await _firestore
            .collection('bookings')
            .where('serviceId', isEqualTo: serviceId)
            .where('bookingDate', isEqualTo: Timestamp.fromDate(dateTime))
            .where('status', whereIn: ['confirmed', 'pending']).get();

        return bookings.docs.isEmpty;
      } catch (e) {
        print(
            'FIREBASE INDEX ERROR: $e'); // Ce print affichera l'URL de l'index
        return false;
      }
    } catch (e) {
      print('FIREBASE ERROR: $e');
      return false;
    }
  }

  List<DateTime> _generateTimeSlotsForDay(
    AvailabilityRuleModel rule,
    DateTime date,
    int serviceDuration,
  ) {
    final List<DateTime> slots = [];
    final now = DateTime.now();

    print('DEBUG: Generating slots for ${date.toString()}');
    print('DEBUG: Service duration: $serviceDuration minutes');

    // Créer le premier créneau de la journée
    var currentSlot = DateTime(
      date.year,
      date.month,
      date.day,
      rule.startTime.hours,
      rule.startTime.minutes,
    );

    // Créer l'heure de fin
    final endTime = DateTime(
      date.year,
      date.month,
      date.day,
      rule.endTime.hours,
      rule.endTime.minutes,
    );

    print('DEBUG: Start time: ${currentSlot.toString()}');
    print('DEBUG: End time: ${endTime.toString()}');

    while (currentSlot.isBefore(endTime)) {
      // Pour aujourd'hui, ignorer les créneaux passés
      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year &&
          currentSlot.isBefore(now)) {
        currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
        continue;
      }

      slots.add(currentSlot);
      currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
    }

    print('DEBUG: Generated ${slots.length} slots');
    return slots;
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
          bool isAvailable = true;

          // Vérifier les réservations existantes
          final bookings = await _firestore
              .collection('bookings')
              .where('serviceId', isEqualTo: serviceId)
              .where('bookingDate', isEqualTo: Timestamp.fromDate(slot))
              .where('status', whereIn: ['confirmed', 'pending']).get();

          if (bookings.docs.isEmpty) {
            availableSlots.add(slot);
          }
        }
      }

      return availableSlots;
    } catch (e) {
      print('ERROR: $e');
      return [];
    }
  }
}
