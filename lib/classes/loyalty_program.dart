import 'package:cloud_firestore/cloud_firestore.dart';

enum LoyaltyProgramType { visits, points, amount }

class LoyaltyProgram {
  final String id;
  final String companyId;
  final LoyaltyProgramType type;
  final int targetValue;
  final double rewardValue;
  final bool isPercentage;
  final Map<int, LoyaltyTier>? tiers;
  final DateTime createdAt;
  final String status;
  final double? minPurchaseAmount;
  final int totalMembers;
  final int activeMembers;
  final int totalRewards;
  final double averageValue;
  final int totalEarned;
  final int totalRedeemed;
  final double engagementRate;

  LoyaltyProgram({
    required this.id,
    required this.companyId,
    required this.type,
    required this.targetValue,
    required this.rewardValue,
    required this.isPercentage,
    this.tiers,
    required this.createdAt,
    this.status = 'active',
    this.minPurchaseAmount,
    this.totalMembers = 0,
    this.activeMembers = 0,
    this.totalRewards = 0,
    this.averageValue = 0,
    this.totalEarned = 0,
    this.totalRedeemed = 0,
    this.engagementRate = 0,
  });

  factory LoyaltyProgram.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    Map<int, LoyaltyTier>? parsedTiers;
    if (data['tiers'] != null) {
      parsedTiers = Map.fromEntries(
        (data['tiers'] as Map<String, dynamic>).entries.map(
              (e) => MapEntry(
                int.parse(e.key),
                LoyaltyTier.fromMap(e.value as Map<String, dynamic>),
              ),
            ),
      );
    }

    return LoyaltyProgram(
      id: doc.id,
      companyId: data['companyId'],
      type: _typeFromString(data['type']),
      targetValue: data['targetValue'] ?? 0,
      rewardValue: (data['rewardValue'] ?? 0).toDouble(),
      isPercentage: data['isPercentage'] ?? false,
      tiers: parsedTiers,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
      minPurchaseAmount: (data['minPurchaseAmount'] ?? 0).toDouble(),
      totalMembers: data['totalMembers'] ?? 0,
      activeMembers: data['activeMembers'] ?? 0,
      totalRewards: data['totalRewards'] ?? 0,
      averageValue: (data['averageValue'] ?? 0).toDouble(),
      totalEarned: data['totalEarned'] ?? 0,
      totalRedeemed: data['totalRedeemed'] ?? 0,
      engagementRate: (data['engagementRate'] ?? 0).toDouble(),
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
      'tiers':
          tiers?.map((key, value) => MapEntry(key.toString(), value.toMap())),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'minPurchaseAmount': minPurchaseAmount,
      'totalMembers': totalMembers,
      'activeMembers': activeMembers,
      'totalRewards': totalRewards,
      'averageValue': averageValue,
      'totalEarned': totalEarned,
      'totalRedeemed': totalRedeemed,
      'engagementRate': engagementRate,
    };
  }
}

class LoyaltyTier {
  final int points;
  final double reward;
  final bool isPercentage;

  LoyaltyTier({
    required this.points,
    required this.reward,
    required this.isPercentage,
  });

  factory LoyaltyTier.fromMap(Map<String, dynamic> map) {
    return LoyaltyTier(
      points: map['points'],
      reward: map['reward'].toDouble(),
      isPercentage: map['isPercentage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'points': points,
      'reward': reward,
      'isPercentage': isPercentage,
    };
  }
}
