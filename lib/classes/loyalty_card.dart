import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyCard {
  final String id;
  final String customerId;
  final String loyaltyProgramId;
  final String companyId;
  final double currentValue;
  final DateTime createdAt;
  final DateTime? lastUsed;
  final LastTransaction? lastTransaction;
  final double totalEarned;
  final double totalRedeemed;
  final String status;

  LoyaltyCard({
    required this.id,
    required this.customerId,
    required this.loyaltyProgramId,
    required this.companyId,
    required this.currentValue,
    required this.createdAt,
    this.lastUsed,
    this.lastTransaction,
    required this.totalEarned,
    required this.totalRedeemed,
    this.status = 'active',
  });

  factory LoyaltyCard.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return LoyaltyCard(
      id: doc.id,
      customerId: data['customerId'],
      loyaltyProgramId: data['loyaltyProgramId'],
      companyId: data['companyId'],
      currentValue: (data['currentValue'] ?? 0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUsed: data['lastUsed'] != null
          ? (data['lastUsed'] as Timestamp).toDate()
          : null,
      lastTransaction: data['lastTransaction'] != null
          ? LastTransaction.fromMap(data['lastTransaction'])
          : null,
      totalEarned: (data['totalEarned'] ?? 0).toDouble(),
      totalRedeemed: (data['totalRedeemed'] ?? 0).toDouble(),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'loyaltyProgramId': loyaltyProgramId,
      'companyId': companyId,
      'currentValue': currentValue,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUsed': lastUsed != null ? Timestamp.fromDate(lastUsed!) : null,
      'lastTransaction': lastTransaction?.toMap(),
      'totalEarned': totalEarned,
      'totalRedeemed': totalRedeemed,
      'status': status,
    };
  }

  LoyaltyCard copyWith({
    String? id,
    String? customerId,
    String? loyaltyProgramId,
    String? companyId,
    double? currentValue,
    DateTime? createdAt,
    DateTime? lastUsed,
    LastTransaction? lastTransaction,
    double? totalEarned,
    double? totalRedeemed,
    String? status,
  }) {
    return LoyaltyCard(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      loyaltyProgramId: loyaltyProgramId ?? this.loyaltyProgramId,
      companyId: companyId ?? this.companyId,
      currentValue: currentValue ?? this.currentValue,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      lastTransaction: lastTransaction ?? this.lastTransaction,
      totalEarned: totalEarned ?? this.totalEarned,
      totalRedeemed: totalRedeemed ?? this.totalRedeemed,
      status: status ?? this.status,
    );
  }
}

class LastTransaction {
  final DateTime date;
  final double amount;
  final String type;

  LastTransaction({
    required this.date,
    required this.amount,
    required this.type,
  });

  factory LastTransaction.fromMap(Map<String, dynamic> map) {
    return LastTransaction(
      date: (map['date'] as Timestamp).toDate(),
      amount: map['amount'].toDouble(),
      type: map['type'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'amount': amount,
      'type': type,
    };
  }
}
