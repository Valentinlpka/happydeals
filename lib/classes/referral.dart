import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class Reward {
  final String type;
  final String value;
  final String? details;

  Reward({
    required this.type,
    required this.value,
    this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'details': details,
    };
  }

  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      type: map['type'] ?? '',
      value: map['value'] ?? '',
      details: map['details'],
    );
  }
}

class Referral extends Post {
  final String title;
  final String searchText;
  final String description;
  final String? participationConditions;
  final String rewardRecipient;
  final Reward sponsorReward;
  final Reward refereeReward;
  final DateTime endDate;
  final int? maxReferrals;
  final String? termsLink;
  final String? image;
  final List<String>? tags;
  final String? additionalInfo;
  final Map<String, dynamic> companyAddress;

  Referral({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.searchText,
    required this.description,
    this.participationConditions,
    required this.rewardRecipient,
    required this.sponsorReward,
    required this.refereeReward,
    required this.endDate,
    this.maxReferrals,
    this.termsLink,
    this.image,
    this.tags,
    this.additionalInfo,
    required super.companyId,
    required super.companyName,
    required super.companyLogo,
    required this.companyAddress,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
  }) : super(
          type: 'referral',
        );

  factory Referral.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Referral(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      title: data['title'] ?? '',
      searchText: data['searchText'] ?? '',
      description: data['description'] ?? '',
      participationConditions: data['participationConditions'],
      rewardRecipient: data['rewardRecipient'] ?? 'both',
      sponsorReward: Reward.fromMap(data['sponsorReward'] ?? {}),
      refereeReward: Reward.fromMap(data['refereeReward'] ?? {}),
      endDate: (data['endDate'] as Timestamp).toDate(),
      maxReferrals: data['maxReferrals'],
      termsLink: data['termsLink'],
      image: data['image'],
      tags: List<String>.from(data['tags'] ?? []),
      additionalInfo: data['additionalInfo'],
      companyId: data['companyId'] ?? '',
      companyName: data['companyName'] ?? '',
      companyLogo: data['companyLogo'] ?? '',
      companyAddress: data['companyAddress'] ?? {},
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
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
      'description': description,
      'participationConditions': participationConditions,
      'rewardRecipient': rewardRecipient,
      'sponsorReward': sponsorReward.toMap(),
      'refereeReward': refereeReward.toMap(),
      'endDate': Timestamp.fromDate(endDate),
      'maxReferrals': maxReferrals,
      'termsLink': termsLink,
      'image': image,
      'tags': tags,
      'additionalInfo': additionalInfo,
      'companyName': companyName,
      'companyLogo': companyLogo,
      'companyAddress': companyAddress,
    });
    return map;
  }
}
