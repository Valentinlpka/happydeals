import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class SharedPost extends Post {
  SharedPost({
    required super.id,
    required super.companyId,
    required super.timestamp,
    required String super.originalPostId,
    required String super.sharedBy,
    required DateTime super.sharedAt,
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
    );
  }
}