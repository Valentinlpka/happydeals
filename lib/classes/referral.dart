import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class Referral extends Post {
  final String title;
  final String searchText;
  final String description;
  final String sponsorBenefit;
  final String refereeBenefit;
  final String image;
  final DateTime dateFinal;

  Referral({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.searchText,
    required this.dateFinal,
    required this.description,
    required this.sponsorBenefit,
    required this.refereeBenefit,
    required super.companyId,
    required this.image,
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
      title: data['title'],
      searchText: data['searchText'],
      description: data['description'],
      sponsorBenefit: data['sponsorBenefit'],
      refereeBenefit: data['refereeBenefit'],
      companyId: data['companyId'],
      image: data['image'],
      dateFinal: (data['date_final'] as Timestamp).toDate(),
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
      'companyId': companyId,
      'sponsorBenefit': sponsorBenefit,
      'refereeBenefit': refereeBenefit,
      'image': image,
      'date_final': Timestamp.fromDate(dateFinal),
    });
    return map;
  }
}
