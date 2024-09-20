import 'package:cloud_firestore/cloud_firestore.dart';

enum LoyaltyProgramType { visits, points, amount }

class LoyaltyProgram {
  final String id;
  final String companyId;
  final LoyaltyProgramType type;
  final int targetValue;
  final double rewardValue;
  final bool isPercentage;
  final Map<int, double>? tiers;

  LoyaltyProgram({
    required this.id,
    required this.companyId,
    required this.type,
    required this.targetValue,
    required this.rewardValue,
    required this.isPercentage,
    this.tiers,
  });

  factory LoyaltyProgram.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return LoyaltyProgram(
      id: doc.id,
      companyId: data['companyId'],
      type: _typeFromString(data['type']),
      targetValue: data['targetValue'],
      rewardValue: data['rewardValue'].toDouble(),
      isPercentage: data['isPercentage'],
      tiers:
          data['tiers'] != null ? Map<int, double>.from(data['tiers']) : null,
    );
  }

  static LoyaltyProgramType _typeFromString(String type) {
    switch (type) {
      case 'visits':
        return LoyaltyProgramType.visits;
      case 'points':
        return LoyaltyProgramType.points;
      case 'amount':
        return LoyaltyProgramType.amount;
      default:
        throw ArgumentError('Unknown loyalty program type: $type');
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'type': type.toString().split('.').last,
      'targetValue': targetValue,
      'rewardValue': rewardValue,
      'isPercentage': isPercentage,
      'tiers': tiers,
    };
  }
}
