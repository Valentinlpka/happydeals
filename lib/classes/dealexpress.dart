import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class ExpressDeal extends Post {
  final String title;
  final String searchText;
  List<DateTime> pickupTimes; // Remplace pickupTime
  final String content;
  final int basketCount;
  final String basketType;
  final int price;
  int availableBaskets;
  final String stripeAccountId;

  ExpressDeal({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.basketType,
    required this.searchText,
    required this.pickupTimes,
    required this.content,
    required super.companyId,
    required this.basketCount,
    required this.price,
    required this.availableBaskets,
    required this.stripeAccountId,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
  }) : super(
          type: 'express_deal',
        );

  factory ExpressDeal.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpressDeal(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      title: data['title'],
      searchText: data['searchText'],
      pickupTimes: (data['pickupTimes'] as List<dynamic>?)
              ?.map((item) => (item as Timestamp).toDate())
              .toList() ??
          [],
      content: data['content'],
      companyId: data['companyId'],
      basketCount: data['basketCount'],
      basketType: data['basketType'],
      price: data['price'],
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      availableBaskets: data['basketCount'],
      stripeAccountId: data['stripeAccountId'] ?? '',
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'searchText': searchText,
      'pickupTimes':
          pickupTimes.map((time) => Timestamp.fromDate(time)).toList(),
      'content': content,
      'basketType': basketType,
      'basketCount': basketCount,
      'price': price,
      'stripeAccountId': stripeAccountId,
    });
    return map;
  }

  Future<String?> reserve(String userId, DateTime selectedPickupTime) async {
    if (availableBaskets > 0) {
      final reservationId =
          FirebaseFirestore.instance.collection('reservations').doc().id;
      final validationCode = generateValidationCode();
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final dealRef =
            FirebaseFirestore.instance.collection('express_deals').doc(id);
        final dealSnapshot = await transaction.get(dealRef);
        if (dealSnapshot.data()!['availableBaskets'] > 0) {
          transaction
              .update(dealRef, {'availableBaskets': FieldValue.increment(-1)});
          transaction.set(
              FirebaseFirestore.instance
                  .collection('reservations')
                  .doc(reservationId),
              {
                'dealId': id,
                'userId': userId,
                'companyId': companyId,
                'reservationTime': FieldValue.serverTimestamp(),
                'stripeAccountId': stripeAccountId,
                'validationCode': validationCode,
                'isValidated': false,
                'selectedPickupTime': Timestamp.fromDate(selectedPickupTime),
              });
          availableBaskets--;
          return validationCode;
        }
      });
      return validationCode;
    }
    return null;
  }

  String generateValidationCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }
}
