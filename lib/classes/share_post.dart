import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class SharedPost extends Post {
  @override
  final String originalPostId;
  @override
  final String sharedBy;
  @override
  final DateTime sharedAt;
  final String? comment; // Déclaré comme une propriété de la classe

  SharedPost({
    required super.id,
    required super.companyId,
    required super.timestamp,
    required this.originalPostId,
    required this.sharedBy,
    required this.sharedAt,
    this.comment, // Maintenant correctement inclus dans le constructeur
  }) : super(
          type: 'shared',
        );
  factory SharedPost.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedPost(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      originalPostId: data['originalPostId'] ?? '',
      sharedBy: data['sharedBy'] ?? '',
      sharedAt: data['sharedAt'] != null
          ? (data['sharedAt'] as Timestamp).toDate()
          : DateTime.now(),
      comment: data['comment'] ?? '',
    );
  }
}
