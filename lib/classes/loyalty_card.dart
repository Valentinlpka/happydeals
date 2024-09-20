import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyCard {
  final String id;
  final String customerId;
  final String loyaltyProgramId;
  final String companyId;
  int currentValue;

  LoyaltyCard({
    required this.id,
    required this.customerId,
    required this.loyaltyProgramId,
    required this.companyId,
    required this.currentValue,
  });

  factory LoyaltyCard.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return LoyaltyCard(
      id: doc.id,
      customerId: data['customerId'],
      loyaltyProgramId: data['loyaltyProgramId'],
      companyId: data['companyId'],
      currentValue: data['currentValue'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'loyaltyProgramId': loyaltyProgramId,
      'companyId': companyId,
      'currentValue': currentValue,
    };
  }

  LoyaltyCard copyWith({
    String? id,
    String? customerId,
    String? loyaltyProgramId,
    String? companyId,
    int? currentValue,
  }) {
    return LoyaltyCard(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      loyaltyProgramId: loyaltyProgramId ?? this.loyaltyProgramId,
      companyId: companyId ?? this.companyId,
      currentValue: currentValue ?? this.currentValue,
    );
  }
}
