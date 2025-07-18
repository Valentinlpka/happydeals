import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class SharedPost extends Post {
  SharedPost({
    required super.id,
    required super.companyId,
    required super.timestamp,
    required super.originalPostId,
    required super.sharedBy,
    required super.sharedAt,
    required super.companyName,
    required super.companyLogo,
    super.comment,
  }) : super(type: 'shared');

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
      companyName: data['companyName'] ?? '',
      companyLogo: data['companyLogo'] ?? '',
    );
  }
}
