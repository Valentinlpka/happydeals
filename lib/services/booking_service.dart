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
      String serviceId, DateTime date, int duration) async {
    try {
      print(
          'Début getAvailableTimeSlots pour serviceId: $serviceId, date: $date');

      // Récupérer la règle de disponibilité du service
      final rulesQuery = await _firestore
          .collection('availabilityRules')
          .where('serviceId', isEqualTo: serviceId)
          .where('isActive', isEqualTo: true)
          .get();

      if (rulesQuery.docs.isEmpty) return {};

      // Récupérer tous les employés qui peuvent faire ce service
      final employeesQuery = await _firestore
          .collection('employees')
          .where('services', arrayContains: serviceId)
          .where('isActive', isEqualTo: true)
          .get();

      final totalEmployees = employeesQuery.docs.length;
      if (totalEmployees == 0) return {};

      // Générer tous les créneaux possibles
      final rule = AvailabilityRuleModel.fromMap(rulesQuery.docs.first.data());
      final possibleSlots = generateTimeSlotsForDay(rule, date, duration);

      Map<DateTime, int> availableSlotsCount = {};

      // Pour chaque créneau possible
      for (var slot in possibleSlots) {
        // Compter combien de réservations existent déjà pour ce créneau
        final existingBookings = await _firestore
            .collection('bookings')
            .where('serviceId', isEqualTo: serviceId)
            .where('bookingDateTime', isEqualTo: Timestamp.fromDate(slot))
            .where('status', whereIn: ['confirmed', 'pending']).get();

        final bookedCount = existingBookings.docs.length;
        final availableCount = totalEmployees - bookedCount;

        // Si il reste des places disponibles, ajouter le créneau
        if (availableCount > 0) {
          availableSlotsCount[slot] = availableCount;
        }
      }

      print('Créneaux disponibles: $availableSlotsCount');
      return availableSlotsCount;
    } catch (e) {
      print('Erreur: $e');
      return {};
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
