import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/review.dart';

class ReviewService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addReview(Review review) async {
    await _firestore.collection('reviews').add(review.toMap());
    notifyListeners();
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
