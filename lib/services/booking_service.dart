import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/availibility_rule.dart';
import 'package:happy/classes/booking.dart';
import 'package:happy/services/promo_test.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PromoCodeService _promoService = PromoCodeService();

  // Récupérer les créneaux disponibles pour un service
  Stream<List<AvailabilityRuleModel>> getServiceAvailabilityRules(
      String serviceId) {
    return _firestore
        .collection('availabilityRules')
        .where('serviceId', isEqualTo: serviceId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AvailabilityRuleModel.fromMap(doc.data()))
          .toList();
    });
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

    // Vérifier si c'est un jour travaillé
    if (!rule.workDays.contains(date.weekday)) {
      return [];
    }

    // Vérifier les dates exceptionnelles
    if (rule.exceptionalDates.any((ed) =>
        ed.date.year == date.year &&
        ed.date.month == date.month &&
        ed.date.day == date.day)) {
      return [];
    }

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
    if (date.isBefore(DateTime(now.year, now.month, now.day))) {
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

      // Vérifier si le créneau est pendant une pause
      bool isDuringBreak = false;
      for (var breakTime in rule.breakTimes) {
        final breakStart = DateTime(
          date.year,
          date.month,
          date.day,
          breakTime.start.hours,
          breakTime.start.minutes,
        );
        final breakEnd = DateTime(
          date.year,
          date.month,
          date.day,
          breakTime.end.hours,
          breakTime.end.minutes,
        );

        // Vérifier si le créneau ou sa durée chevauche une pause
        if ((currentSlot.isAfter(breakStart) &&
                currentSlot.isBefore(breakEnd)) ||
            (currentSlot
                    .add(Duration(minutes: serviceDuration))
                    .isAfter(breakStart) &&
                currentSlot
                    .add(Duration(minutes: serviceDuration))
                    .isBefore(breakEnd)) ||
            (currentSlot.isBefore(breakStart) &&
                currentSlot
                    .add(Duration(minutes: serviceDuration))
                    .isAfter(breakEnd))) {
          isDuringBreak = true;
          break;
        }
      }

      if (!isDuringBreak) {
        slots.add(currentSlot);
      }

      currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
    }

    return slots;
  }

  Future<Map<DateTime, int>> getAvailableTimeSlots(
    String businessId,
    String serviceId,
    DateTime date,
    int serviceDuration,
  ) async {
    try {
      // 1. Récupérer le planning de l'entreprise
      final scheduleDoc = await _firestore
          .collection('businessSchedules')
          .where('businessId', isEqualTo: businessId)
          .get();

      if (scheduleDoc.docs.isEmpty) {
        return {};
      }

      final schedule = scheduleDoc.docs.first.data();
      // Correction de l'indexation des jours : 0 = Dimanche, 1 = Lundi, etc.
      final weekDay = date.weekday % 7; // 0-6 où 0 est dimanche

      // 2. Vérifier si on utilise un planning uniforme ou journalier
      final bool useUniformSchedule = schedule['useUniformSchedule'] ?? true;

      // 3. Obtenir les horaires pour ce jour
      String openTime;
      String closeTime;
      bool isOpen;

      if (useUniformSchedule) {
        openTime = schedule['openTime'];
        closeTime = schedule['closeTime'];
        isOpen = schedule['workDays'].contains(weekDay);
      } else {
        final dailySchedules =
            schedule['dailySchedules'] as Map<String, dynamic>;
        final dailySchedule = dailySchedules[weekDay.toString()];
        if (dailySchedule == null) {
          return {};
        }
        openTime = dailySchedule['openTime'] as String;
        closeTime = dailySchedule['closeTime'] as String;
        isOpen = dailySchedule['isOpen'] as bool;
      }

      if (!isOpen) {
        return {};
      }

      // 4. Vérifier les exceptions
      if (_isExceptionDay(date, schedule['exceptions'] ?? [])) {
        return {};
      }

      final simultaneousSlots = schedule['simultaneousSlots'] as int;
      final breaks = schedule['breaks'] as List<dynamic>? ?? [];

      Map<DateTime, int> availableSlots = {};

      final parsedOpenTime = _parseTimeString(openTime);
      final parsedCloseTime = _parseTimeString(closeTime);

      DateTime currentSlot = DateTime(
        date.year,
        date.month,
        date.day,
        parsedOpenTime.hour,
        parsedOpenTime.minute,
      );

      final endTime = DateTime(
        date.year,
        date.month,
        date.day,
        parsedCloseTime.hour,
        parsedCloseTime.minute,
      );

      // 5. Vérifier chaque créneau
      while (currentSlot
              .add(Duration(minutes: serviceDuration))
              .isBefore(endTime) ||
          currentSlot
              .add(Duration(minutes: serviceDuration))
              .isAtSameMomentAs(endTime)) {
        // Ignorer les créneaux passés pour aujourd'hui
        if (date.day == DateTime.now().day &&
            currentSlot.isBefore(DateTime.now())) {
          currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
          continue;
        }

        // Vérifier si le créneau n'est pas pendant une pause
        if (!_isInBreakTime(currentSlot, breaks, serviceDuration)) {
          final bookings = await _getExistingBookings(serviceId, currentSlot);
          final availableCount = simultaneousSlots - bookings;

          if (availableCount > 0) {
            availableSlots[currentSlot] = availableCount;
          }
        }

        currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
      }

      return availableSlots;
    } catch (e) {
      return {};
    }
  }

  bool _isExceptionDay(DateTime date, List<dynamic> exceptions) {
    return exceptions.any((exception) {
      final exceptionDate = (exception['date'] as Timestamp).toDate();
      return exceptionDate.year == date.year &&
          exceptionDate.month == date.month &&
          exceptionDate.day == date.day &&
          exception['type'] == 'closed';
    });
  }

  DateTime _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return DateTime(
      2000,
      1,
      1,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  bool _isInBreakTime(DateTime slot, List<dynamic> breaks, int duration) {
    if (breaks.isEmpty) return false;

    final slotTime = DateTime(2000, 1, 1, slot.hour, slot.minute);
    final slotEnd = slotTime.add(Duration(minutes: duration));

    return breaks.any((breakTime) {
      final breakStart = _parseTimeString(breakTime['start']);
      final breakEnd = _parseTimeString(breakTime['end']);

      // Un créneau est pendant une pause si :
      // 1. Le début du créneau est pendant la pause
      // 2. La fin du créneau est pendant la pause
      // 3. Le créneau englobe complètement la pause
      return (slotTime.isAtSameMomentAs(breakStart) ||
              (slotTime.isAfter(breakStart) && slotTime.isBefore(breakEnd))) ||
          (slotEnd.isAfter(breakStart) && slotEnd.isBefore(breakEnd)) ||
          (slotTime.isBefore(breakStart) && slotEnd.isAfter(breakEnd));
    });
  }

  Future<int> _getExistingBookings(String businessId, DateTime slot) async {
    try {
      // Vérifier uniquement les réservations pour ce service et avec des statuts valides
      final bookings = await _firestore
          .collection('bookings')
          .where('serviceId', isEqualTo: businessId)
          .where('bookingDateTime', isEqualTo: Timestamp.fromDate(slot))
          .where('status', whereIn: ['confirmed', 'pending']).get();

      return bookings.docs.length;
    } catch (e) {
      if (e is AssertionError) {}
      return 0;
    }
  }

  // Nouvelle méthode pour réserver un créneau avec un employé spécifique
  Future<String?> findAvailableEmployee(
    String serviceId,
    DateTime slot,
  ) async {
    try {
      final employeesQuery = await _firestore
          .collection('employees')
          .where('services', arrayContains: serviceId)
          .where('isActive', isEqualTo: true)
          .get();

      for (var employeeDoc in employeesQuery.docs) {
        final employeeId = employeeDoc.id;

        // Vérifier les règles de disponibilité
        final rulesQuery = await _firestore
            .collection('availabilityRules')
            .where('employeeId', isEqualTo: employeeId)
            .where('isActive', isEqualTo: true)
            .get();

        if (rulesQuery.docs.isEmpty) continue;

        // Vérifier si l'employé a déjà une réservation
        final existingBookings = await _firestore
            .collection('bookings')
            .where('employeeId', isEqualTo: employeeId)
            .where('bookingDateTime', isEqualTo: Timestamp.fromDate(slot))
            .where('status', whereIn: ['confirmed', 'pending']).get();

        if (existingBookings.docs.isEmpty) {
          return employeeId; // Retourner le premier employé disponible
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<double> applyPromoCode(
    String code,
    String companyId,
    String userId,
    String serviceId,
    double originalPrice,
  ) async {
    try {
      // Valider et récupérer les détails du code promo
      final promoDetails = await _promoService.validateAndGetPromoCode(
        code,
        companyId,
        userId,
        serviceId: serviceId,
        cartTotal: originalPrice,
      );

      if (promoDetails == null) {
        throw Exception('Code promo invalide');
      }

      // Calculer la réduction
      final finalPrice = originalPrice -
          _promoService.calculateDiscount(promoDetails, originalPrice);

      // Marquer le code comme utilisé uniquement si tout est OK
      // await _promoService.usePromoCode(promoDetails['id'], userId);

      return finalPrice;
    } catch (e) {
      rethrow;
    }
  }

  // Méthode pour créer une réservation avec code promo
  Future<void> createBookingWithPromo(
    String userId,
    String serviceId,
    DateTime bookingDateTime,
    String? promoCode,
    double originalPrice,
    double finalPrice,
  ) async {
    try {
      final bookingRef = _firestore.collection('bookings').doc();

      final bookingData = {
        'id': bookingRef.id,
        'userId': userId,
        'serviceId': serviceId,
        'bookingDateTime': Timestamp.fromDate(bookingDateTime),
        'status': 'pending',
        'originalPrice': originalPrice,
        'finalPrice': finalPrice,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (promoCode != null) {
        bookingData['promoCode'] = promoCode;
        bookingData['discount'] = originalPrice - finalPrice;
      }

      await bookingRef.set(bookingData);
    } catch (e) {
      rethrow;
    }
  }
}
