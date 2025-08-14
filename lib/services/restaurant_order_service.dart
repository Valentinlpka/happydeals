import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/models/restaurant_order.dart';

class RestaurantOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Récupère toutes les commandes de restaurant d'un utilisateur
  Stream<List<RestaurantOrder>> getUserRestaurantOrders(String userId) {
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'restaurant_order')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RestaurantOrder.fromFirestore(doc))
          .toList();
    });
  }

  /// Récupère une commande de restaurant spécifique
  Future<RestaurantOrder?> getRestaurantOrder(String orderId) async {
    try {
      final doc = await _firestore
          .collection('orders')
          .doc(orderId)
          .get();
      
      if (doc.exists) {
        return RestaurantOrder.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Erreur lors de la récupération de la commande: $e');
      return null;
    }
  }

  /// Met à jour le statut d'une commande de restaurant
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur lors de la mise à jour du statut: $e');
      rethrow;
    }
  }

  /// Annule une commande de restaurant
  Future<void> cancelOrder(String orderId, String reason) async {
    try {
      await _firestore
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Erreur lors de l\'annulation de la commande: $e');
      rethrow;
    }
  }
} 