import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/availibility_rule.dart';
import 'package:happy/classes/booking.dart';
import 'package:happy/services/promo_test.dart';
import 'package:intl/intl.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PromoCodeService _promoService = PromoCodeService();

  // Récupérer les créneaux disponibles pour un service
  Stream<List<AvailabilityRuleModel>> getServiceAvailabilityRules(
      String serviceId) {
    print('Recherche des règles pour le service: $serviceId');
    return _firestore
        .collection('availabilityRules')
        .where('serviceId', isEqualTo: serviceId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      print('Règles trouvées: ${snapshot.docs.length}');
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
      print(
          'Génération des créneaux pour le service $serviceId de cette societe $businessId à la date $date');

      // 1. Récupérer le planning de l'entreprise
      final scheduleDoc = await _firestore
          .collection('businessSchedules')
          .where('businessId', isEqualTo: businessId)
          .get();

      if (scheduleDoc.docs.isEmpty) {
        print('Aucun planning trouvé pour l\'entreprise');
        return {};
      }

      final schedule = scheduleDoc.docs.first.data();
      final weekDay = date.weekday == 7 ? 0 : date.weekday;

      // 2. Vérifier si le jour est travaillé
      if (!schedule['workDays'].contains(weekDay)) {
        print('Jour non travaillé');
        return {};
      }

      // 3. Vérifier les exceptions
      if (_isExceptionDay(date, schedule['exceptions'] ?? [])) {
        print('Jour d\'exception');
        return {};
      }

      // 4. Générer les créneaux disponibles
      final openTime = _parseTimeString(schedule['openTime']);
      final closeTime = _parseTimeString(schedule['closeTime']);
      final simultaneousSlots = schedule['simultaneousSlots'] as int;

      Map<DateTime, int> availableSlots = {};
      DateTime currentSlot = DateTime(
        date.year,
        date.month,
        date.day,
        openTime.hour,
        openTime.minute,
      );

      final endTime = DateTime(
        date.year,
        date.month,
        date.day,
        closeTime.hour,
        closeTime.minute,
      );
      // 5. Vérifier chaque créneau
      while (currentSlot
          .add(Duration(minutes: serviceDuration))
          .isBefore(endTime)) {
        // Ignorer les créneaux passés pour aujourd'hui
        if (date.day == DateTime.now().day &&
            currentSlot.isBefore(DateTime.now())) {
          currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
          continue;
        }

        // Vérifier si le créneau n'est pas pendant une pause
        if (!_isInBreakTime(
            currentSlot, schedule['breaks'] ?? [], serviceDuration)) {
          final bookings = await _getExistingBookings(businessId, currentSlot);
          final availableCount = simultaneousSlots - bookings;

          if (availableCount > 0) {
            availableSlots[currentSlot] = availableCount;
          }
        }

        currentSlot = currentSlot.add(Duration(minutes: serviceDuration));
      }

      print('Créneaux générés: ${availableSlots.length}');
      return availableSlots;
    } catch (e) {
      print('Erreur lors de la génération des créneaux: $e');
      return {};
    }
  }

  bool _isExceptionDay(DateTime date, List<dynamic> exceptions) {
    return exceptions.any((exception) {
      final exceptionDate = (exception['date'] as Timestamp).toDate();
      return exceptionDate.year == date.year &&
          exceptionDate.month == date.month &&
          exceptionDate.day == date.day;
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
    final slotTime = DateTime(2000, 1, 1, slot.hour, slot.minute);
    final slotEnd = slotTime.add(Duration(minutes: duration));

    return breaks.any((breakTime) {
      final breakStart = _parseTimeString(breakTime['start']);
      final breakEnd = _parseTimeString(breakTime['end']);

      return (slotTime.isAtSameMomentAs(breakStart) ||
              slotTime.isAfter(breakStart) && slotTime.isBefore(breakEnd)) ||
          (slotEnd.isAfter(breakStart) && slotEnd.isBefore(breakEnd)) ||
          (slotTime.isBefore(breakStart) && slotEnd.isAfter(breakEnd));
    });
  }

  Future<int> _getExistingBookings(String businessId, DateTime slot) async {
    try {
      // 1. D'abord, récupérer tous les services de l'entreprise
      final servicesQuery = await _firestore
          .collection('services')
          .where('professionalId', isEqualTo: businessId)
          .where('isActive', isEqualTo: true)
          .get();

      final serviceIds = servicesQuery.docs.map((doc) => doc.id).toList();

      // Si aucun service n'est trouvé, retourner 0
      if (serviceIds.isEmpty) {
        print('Aucun service actif trouvé pour l\'entreprise $businessId');
        return 0;
      }

      // 2. Vérifier les réservations pour tous les services de l'entreprise
      final bookings = await _firestore
          .collection('bookings')
          .where('serviceId', whereIn: serviceIds)
          .where('bookingDateTime', isEqualTo: Timestamp.fromDate(slot))
          .get();
      print(
          'Réservations trouvées pour le créneau ${DateFormat('HH:mm').format(slot)}: ${bookings.docs.length}');

      // Logs détaillés pour le debugging
      print('Services trouvés: ${serviceIds.length}');
      print('IDs des services: $serviceIds');

      return bookings.docs.length;
    } catch (e) {
      print('Erreur lors de la vérification des réservations existantes: $e');
      if (e is AssertionError) {
        print('Détails de l\'erreur d\'assertion: ${e.message}');
      }
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
      print('Erreur lors de la recherche d\'un employé disponible: $e');
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
      print('Erreur lors de l\'application du code promo: $e');
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
      print('Erreur lors de la création de la réservation: $e');
      rethrow;
    }
  }
}
