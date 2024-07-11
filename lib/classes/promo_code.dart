// lib/models/promo_code.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCode {
  final String code;
  final int discountPercent;
  final DateTime expirationDate;
  final List<String>
      applicableProductIds; // Nouveauté : liste des IDs de produits applicables

  PromoCode({
    required this.code,
    required this.discountPercent,
    required this.expirationDate,
    required this.applicableProductIds,
  });

  factory PromoCode.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return PromoCode(
      code: doc.id,
      discountPercent: data['discountPercent'] ?? 0.0,
      expirationDate: (data['expirationDate'] as Timestamp).toDate(),
      applicableProductIds:
          List<String>.from(data['applicableProductIds'] ?? []),
    );
  }

  bool isApplicableToProduct(String productId) {
    return applicableProductIds.isEmpty ||
        applicableProductIds.contains(productId);
  }
}
