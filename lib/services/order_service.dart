// lib/services/order_service.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:happy/classes/loyalty_card.dart';
import 'package:happy/classes/loyalty_program.dart';
import 'package:happy/classes/order.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Récupérer une commande spécifique
  Future<Orders> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();

      if (!doc.exists) {
        throw Exception('Commande non trouvée');
      }

      return Orders.fromFirestore(doc);
    } catch (e) {
      throw Exception('Erreur lors de la récupération de la commande: $e');
    }
  }

  // Récupérer toutes les commandes d'un utilisateur

  Stream<List<Orders>> getUserOrders(String userId) {
    try {
      return _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => Orders.fromFirestore(doc)).toList();
      });
    } catch (e) {
      print('Erreur dans getUserOrders: $e');
      // Retourner un stream vide en cas d'erreur
      return Stream.value([]);
    }
  }

  // Récupérer les commandes d'un vendeur
  Stream<List<Orders>> getSellerOrders(String sellerId) {
    return _firestore
        .collection('orders')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Orders.fromFirestore(doc)).toList());
  }

  // Mettre à jour le statut d'une commande
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du statut: $e');
    }
  }

  // Ajouter un code de retrait
  Future<void> addPickupCode(String orderId, String pickupCode) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'pickupCode': pickupCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Erreur lors de l\'ajout du code de retrait: $e');
    }
  }

  Future<void> updateProductStock(List<OrderItem> items) async {
    WriteBatch batch = _firestore.batch();
    for (var item in items) {
      DocumentReference productRef =
          _firestore.collection('products').doc(item.productId);
      batch.update(productRef, {'stock': FieldValue.increment(-item.quantity)});
    }
    await batch.commit();
  }

  Future<void> _updateLoyaltyProgram(String orderId) async {
    try {
      final order = await getOrder(orderId);
      final loyaltyProgramDoc = await _firestore
          .collection('LoyaltyPrograms')
          .where('companyId', isEqualTo: order.sellerId)
          .get();

      if (loyaltyProgramDoc.docs.isNotEmpty) {
        final loyaltyProgram =
            LoyaltyProgram.fromFirestore(loyaltyProgramDoc.docs.first);
        final loyaltyCardDoc = await _firestore
            .collection('LoyaltyCards')
            .where('customerId', isEqualTo: order.userId)
            .where('companyId', isEqualTo: order.sellerId)
            .get();

        if (loyaltyCardDoc.docs.isNotEmpty) {
          final loyaltyCard =
              LoyaltyCard.fromFirestore(loyaltyCardDoc.docs.first);
          int newValue;

          switch (loyaltyProgram.type) {
            case LoyaltyProgramType.visits:
              newValue = loyaltyCard.currentValue + 1;
              break;
            case LoyaltyProgramType.points:
              newValue = loyaltyCard.currentValue +
                  (order.totalPrice ~/ loyaltyProgram.targetValue);
              break;
            case LoyaltyProgramType.amount:
              newValue = loyaltyCard.currentValue + order.totalPrice.toInt();
              break;
          }

          await _firestore
              .collection('LoyaltyCards')
              .doc(loyaltyCard.id)
              .update({'currentValue': newValue});

          if (newValue >= loyaltyProgram.targetValue) {
            await _generateReward(loyaltyCard, loyaltyProgram);
          }
        }
      }
    } catch (e) {}
  }

  Future<void> _generateReward(LoyaltyCard card, LoyaltyProgram program) async {
    // Générer un code promo
    String promoCode = _generatePromoCode();

    await _firestore.collection('PromoCodes').add({
      'code': promoCode,
      'customerId': card.customerId,
      'companyId': card.companyId,
      'value': program.rewardValue,
      'isPercentage': program.isPercentage,
      'usedAt': null,
      'expiresAt': DateTime.now().add(const Duration(days: 30)),
    });

    // Réinitialiser la carte de fidélité
    await _firestore
        .collection('LoyaltyCards')
        .doc(card.id)
        .update({'currentValue': 0});

    // Envoyer une notification au client (à implémenter)
    // sendNotificationToCustomer(card.customerId, promoCode, program.rewardValue);
  }

  String _generatePromoCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random();
    return String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  Future<void> confirmOrderPickup(String orderId, String pickupCode) async {
    try {
      await _functions.httpsCallable('confirmOrderPickup').call({
        'orderId': orderId,
        'pickupCode': pickupCode,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPaymentIntent({
    required int amount,
    required String currency,
    required String connectAccountId,
  }) async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Utilisateur non authentifié');
      }
      final result = await _functions.httpsCallable('createPayment').call({
        'amount': amount,
        'currency': currency,
        'connectAccountId': connectAccountId,
        'userId': user.uid,
      });
      return result.data;
    } catch (e) {
      rethrow;
    }
  }
}
