import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class PromoCodePost extends Post {
  final String code;
  final double value;
  final bool isPercentage;
  final DateTime expiresAt;
  final String description;
  final String? thumbnail;
  final int? maxUses;
  final int currentUses;
  final bool isStoreWide;
  final List<String> applicableProductIds;
  final bool isActive;

  PromoCodePost({
    required super.id,
    required super.companyId,
    required super.timestamp,
    required this.code,
    required this.value,
    required this.isPercentage,
    required this.expiresAt,
    required this.description,
    this.thumbnail,
    this.maxUses,
    this.currentUses = 0,
    required this.isStoreWide,
    required this.applicableProductIds,
    this.isActive = true,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
  }) : super(
          type: 'promo_code',
        );

  factory PromoCodePost.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromoCodePost(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      code: data['code'] ?? '',
      value: (data['value'] ?? 0).toDouble(),
      isPercentage: data['isPercentage'] ?? false,
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      description: data['description'] ?? '',
      thumbnail: data['thumbnail'],
      maxUses: data['maxUses'],
      currentUses: data['currentUses'] ?? 0,
      isStoreWide: data['isStoreWide'] ?? true,
      applicableProductIds:
          List<String>.from(data['applicableProductIds'] ?? []),
      isActive: data['isActive'] ?? true,
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
      'value': value,
      'isPercentage': isPercentage,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'description': description,
      'thumbnail': thumbnail,
      'maxUses': maxUses,
      'currentUses': currentUses,
      'isStoreWide': isStoreWide,
      'applicableProductIds': applicableProductIds,
      'isActive': isActive,
    });
    return map;
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isUsable =>
      isActive && !isExpired && (maxUses == null || currentUses < maxUses!);
}
