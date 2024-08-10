// lib/services/order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:happy/classes/order.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createOrder(Orders order) async {
    try {
      final result = await _functions.httpsCallable('createOrder').call({
        'sellerId': order.sellerId,
        'items': order.items.map((item) => item.toMap()).toList(),
        'totalPrice': order.totalPrice,
        'pickupAddress': order.pickupAddress,
      });

      await updateProductStock(order.items);

      return result.data['orderId'];
    } catch (e) {
      rethrow;
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

  Future<Orders> getOrder(String orderId) async {
    DocumentSnapshot orderDoc =
        await _firestore.collection('orders').doc(orderId).get();

    if (!orderDoc.exists) {
      throw Exception('Commande non trouvée');
    }

    Map<String, dynamic> data = orderDoc.data() as Map<String, dynamic>;

    return Orders(
      id: orderDoc.id,
      userId: data['userId'],
      sellerId: data['sellerId'],
      items: (data['items'] as List)
          .map((item) => OrderItem.fromMap(item))
          .toList(),
      totalPrice: data['totalPrice'].toDouble(),
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      pickupAddress: data['pickupAddress'],
      pickupCode: data['pickupCode'],
    );
  }

  Future<List<Orders>> getUserOrders(String userId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Orders.fromFirestore(doc)).toList();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _functions.httpsCallable('updateOrderStatus').call({
        'orderId': orderId,
        'newStatus': newStatus,
      });
    } catch (e) {
      rethrow;
    }
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
