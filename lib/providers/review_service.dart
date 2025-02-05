import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/review.dart';

class ReviewService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> _hasUserPurchased(String userId, String companyId) async {
    // Vérifier les commandes classiques
    final ordersQuery = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('entrepriseId', isEqualTo: companyId)
        .limit(1)
        .get();

    if (ordersQuery.docs.isNotEmpty) return true;

    // Vérifier les services
    final servicesQuery = await _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('professionalId', isEqualTo: companyId)
        .limit(1)
        .get();

    if (servicesQuery.docs.isNotEmpty) return true;

    // Vérifier les deals express
    final dealsQuery = await _firestore
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .where('companyId', isEqualTo: companyId)
        .limit(1)
        .get();

    return dealsQuery.docs.isNotEmpty;
  }

  Future<void> addReview(Review review) async {
    // Vérifier si l'utilisateur a déjà donné un avis
    final existingReview = await _firestore
        .collection('reviews')
        .where('userId', isEqualTo: review.userId)
        .where('companyId', isEqualTo: review.companyId)
        .get();

    if (existingReview.docs.isNotEmpty) {
      throw Exception('Vous avez déjà donné un avis pour cette entreprise');
    }

    // Vérifier si l'utilisateur a déjà commandé
    final hasPurchased =
        await _hasUserPurchased(review.userId, review.companyId);
    if (!hasPurchased) {
      throw Exception(
          'Vous devez avoir effectué un achat pour laisser un avis');
    }

    await _firestore.collection('reviews').add(review.toMap());
    notifyListeners();
  }

  Future<void> updateReview(
    String reviewId, {
    required double rating,
    required String comment,
  }) async {
    await _firestore.collection('reviews').doc(reviewId).update({
      'rating': rating,
      'comment': comment,
      'createdAt': DateTime.now(),
    });
    notifyListeners();
  }

  Future<void> deleteReview(String reviewId) async {
    await _firestore.collection('reviews').doc(reviewId).delete();
    notifyListeners();
  }

  Future<Review?> getUserReviewForCompany(
      String userId, String companyId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('userId', isEqualTo: userId)
        .where('companyId', isEqualTo: companyId)
        .get();

    if (snapshot.docs.isEmpty) return null;

    var doc = snapshot.docs.first;
    var data = doc.data();

    DocumentSnapshot userSnapshot =
        await _firestore.collection('users').doc(userId).get();
    Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;

    return Review(
      id: doc.id,
      userId: data['userId'],
      companyId: data['companyId'],
      rating: data['rating'].toDouble(),
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userName: '${userData['firstName']} ${userData['lastName']}',
      userPhotoUrl: userData['image_profile'] ?? '',
    );
  }

  Future<List<Review>> getReviewsForCompany(String companyId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .get();

    List<Review> reviews = [];
    for (var doc in snapshot.docs) {
      Map<String, dynamic> data = doc.data();
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(data['userId']).get();
      Map<String, dynamic> userData =
          userSnapshot.data() as Map<String, dynamic>;

      reviews.add(Review(
        id: doc.id,
        userId: data['userId'],
        companyId: data['companyId'],
        rating: data['rating'].toDouble(),
        comment: data['comment'],
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        userName: '${userData['firstName']} ${userData['lastName']}',
        userPhotoUrl: userData['image_profile'] ?? '',
      ));
    }

    return reviews;
  }
}
