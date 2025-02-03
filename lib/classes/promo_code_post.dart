import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class PromoCodeCondition {
  final String type;
  final double value;
  final String? productId;

  PromoCodeCondition({
    required this.type,
    required this.value,
    this.productId,
  });

  factory PromoCodeCondition.fromMap(Map<String, dynamic> map) {
    return PromoCodeCondition(
      type: map['type'] ?? '',
      value: (map['value'] ?? 0).toDouble(),
      productId: map['productId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      if (productId != null) 'productId': productId,
    };
  }
}

class PromoCodePost extends Post {
  final String code;
  final double discountValue;
  final String discountType;
  final String? promoCodeId;
  final String description;
  final DateTime? expiresAt;
  final String? maxUses;
  final int currentUses;
  final String? conditionType;
  final double? conditionValue;
  final String? conditionProductId;
  final bool isActive;
  final bool isPublic;
  final String? sellerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<dynamic> usageHistory;

  PromoCodePost({
    required super.id,
    required super.companyId,
    required super.timestamp,
    required this.code,
    required this.discountValue,
    required this.discountType,
    this.promoCodeId,
    required this.description,
    this.expiresAt,
    this.maxUses,
    this.currentUses = 0,
    this.conditionType,
    this.conditionValue,
    this.conditionProductId,
    this.isActive = true,
    this.isPublic = false,
    this.sellerId,
    this.createdAt,
    this.updatedAt,
    this.usageHistory = const [],
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
  }) : super(type: 'promo_code');

  bool get isPercentage => discountType == 'percentage';

  factory PromoCodePost.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Utiliser createdAt si disponible, sinon timestamp
    DateTime timestamp;
    if (data['createdAt'] != null) {
      timestamp = (data['createdAt'] as Timestamp).toDate();
    } else {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    }

    return PromoCodePost(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      timestamp: timestamp,
      code: data['code'] ?? '',
      discountValue: (data['discountValue'] ?? 0).toDouble(),
      discountType: data['discountType'] ?? 'fixed',
      promoCodeId: data['promoCodeId'],
      description: data['description'] ?? '',
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      maxUses: data['maxUses']?.toString(),
      currentUses: data['currentUses'] ?? 0,
      conditionType: data['conditionType'],
      conditionValue: (data['conditionValue'] ?? 0).toDouble(),
      conditionProductId: data['conditionProductId'],
      isActive: data['isActive'] ?? true,
      isPublic: data['isPublic'] ?? false,
      sellerId: data['sellerId'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      usageHistory: List<dynamic>.from(data['usageHistory'] ?? []),
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((c) => Comment.fromMap(c))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'code': code,
      'discountValue': discountValue,
      'discountType': discountType,
      'promoCodeId': promoCodeId,
      'description': description,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (maxUses != null) 'maxUses': maxUses,
      'currentUses': currentUses,
      if (conditionType != null) 'conditionType': conditionType,
      if (conditionValue != null) 'conditionValue': conditionValue,
      if (conditionProductId != null) 'conditionProductId': conditionProductId,
      'isActive': isActive,
      'isPublic': isPublic,
      if (sellerId != null) 'sellerId': sellerId,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'usageHistory': usageHistory,
    });
    return map;
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isUsable {
    if (!isActive || isExpired) return false;
    if (maxUses == null) return true;

    try {
      final maxUsesInt = int.parse(maxUses!);
      return currentUses < maxUsesInt;
    } catch (e) {
      print('Erreur de conversion maxUses: $e');
      return false;
    }
  }
}
